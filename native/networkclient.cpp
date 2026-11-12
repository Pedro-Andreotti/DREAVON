#include "networkclient.h"

#include <QFile>
#include <QHostAddress>
#include <QNetworkInterface>
#include <QTcpSocket>
#include <functional>

// O D-Bus (NetworkManager) só existe no Linux. Qt define QT_DBUS_LIB quando o módulo DBus é ligado.
#ifdef QT_DBUS_LIB
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#endif

#ifdef Q_OS_WIN
#include "networkinfo_win.h"
#include <QLoggingCategory>
#include <QSet>
// Diagnóstico da rede no Windows, desligado por padrão (ligar com
// QT_LOGGING_RULES="dreavon.network.info=true"). Só contagens e durações, sem nomes, IPs nem ids.
Q_LOGGING_CATEGORY(lcNetwork, "dreavon.network", QtWarningMsg)
#endif

namespace {
#ifdef QT_DBUS_LIB
const QString NM = QStringLiteral("org.freedesktop.NetworkManager");

QVariant unwrap(const QVariant &v) { return v.canConvert<QDBusVariant>() ? v.value<QDBusVariant>().variant() : v; }

// Lê uma propriedade do NetworkManager de forma assíncrona.
void nmProperty(QObject *context, const QString &path, const QString &interface, const QString &name, std::function<void(const QVariant &)> done) {
    auto msg = QDBusMessage::createMethodCall(NM, path, "org.freedesktop.DBus.Properties", "Get");
    msg << interface << name;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg, 2000), context);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, context, [done](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QVariant> reply = *w; w->deleteLater();
        done(reply.isError() ? QVariant() : unwrap(reply.value()));
    });
}
#endif

#ifndef Q_OS_WIN
bool countedInterface(const QString &name) {
    return name != "lo" && !name.startsWith("veth") && !name.startsWith("docker") && !name.startsWith("br-")
        && !name.startsWith("virbr") && !name.startsWith("vnet");
}
#endif
}

NetworkClient::NetworkClient(QObject *parent) : QObject(parent) {
    for (int i = 0; i < 60; ++i) { m_downHistory.append(0.0); m_upHistory.append(0.0); }
    m_rateTimer.setInterval(1000);
    connect(&m_rateTimer, &QTimer::timeout, this, &NetworkClient::sampleRates);
    m_connectionTimer.setInterval(10000);
    connect(&m_connectionTimer, &QTimer::timeout, this, &NetworkClient::refreshConnection);
    m_latencyTimer.setInterval(20000);
    connect(&m_latencyTimer, &QTimer::timeout, this, &NetworkClient::measureLatency);
    m_rateTimer.start(); m_connectionTimer.start(); m_latencyTimer.start();
    sampleRates(); refreshConnection(); measureLatency();
}

QString NetworkClient::formatRate(double bytes) {
    if (bytes < 0) return QStringLiteral("—");
    const double bits = bytes * 8;
    if (bits >= 1e9) return QString::number(bits / 1e9, 'f', 1) + " Gb/s";
    if (bits >= 1e6) return QString::number(bits / 1e6, 'f', bits >= 1e8 ? 0 : 1) + " Mb/s";
    if (bits >= 1e3) return QString::number(bits / 1e3, 'f', 0) + " kb/s";
    return QString::number(bits, 'f', 0) + " b/s";
}

void NetworkClient::sampleRates() {
#ifdef Q_OS_WIN
    // Diferença dos contadores de cada interface física ativa entre duas leituras. Só soma interfaces
    // presentes nas duas: uma interface que surge ou some (troca Wi-Fi/cabo) não gera pico falso.
    QList<NetworkInfoWin::Counter> list;
    int skipped = 0;
    const bool ok = NetworkInfoWin::counters(&list, &skipped);
    const double seconds = m_clock.isValid() ? m_clock.restart() / 1000.0 : 0;
    if (!m_clock.isValid()) m_clock.start();
    QHash<quint64, QPair<quint64, quint64>> current;
    quint64 rx = 0, tx = 0;
    int matched = 0;
    for (const auto &c : list) {
        current.insert(c.luid, {c.rx, c.tx});
        const auto it = m_counters.constFind(c.luid);
        if (it == m_counters.cend() || c.rx < it->first || c.tx < it->second) continue;
        rx += c.rx - it->first; tx += c.tx - it->second; ++matched;
    }
    const bool interfacesChanged = ok && QSet<quint64>(current.keyBegin(), current.keyEnd())
        != QSet<quint64>(m_counters.keyBegin(), m_counters.keyEnd());
    m_counters = current;
    // Sem tabela ou sem interface ativa: indisponível ("—"), nunca 0.
    if (seconds > 0 && matched > 0) { m_down = rx / seconds; m_up = tx / seconds; }
    else { m_down = -1; m_up = -1; }
    m_downHistory.removeFirst(); m_downHistory.append(qMax(0.0, m_down));
    m_upHistory.removeFirst(); m_upHistory.append(qMax(0.0, m_up));
    emit ratesChanged();
    // Interface ligada ou desligada: atualiza nome, tipo e latência já, sem esperar o próximo ciclo.
    if (interfacesChanged && seconds > 0) {
        qCInfo(lcNetwork) << "interfaces contadas:" << current.size() << "ignoradas:" << skipped;
        refreshConnection();
        measureLatency();
    }
#else
    QFile file("/proc/net/dev");
    if (!file.open(QIODevice::ReadOnly)) return;
    quint64 rx = 0, tx = 0;
    const auto lines = file.readAll().split('\n');
    for (int i = 2; i < lines.size(); ++i) {
        const QString line = QString::fromLatin1(lines[i]);
        const QString name = line.section(':', 0, 0).trimmed();
        if (name.isEmpty() || !countedInterface(name)) continue;
        const auto fields = line.section(':', 1).simplified().split(' ');
        if (fields.size() < 9) continue;
        rx += fields[0].toULongLong(); tx += fields[8].toULongLong();
    }
    const double seconds = m_clock.isValid() ? m_clock.restart() / 1000.0 : 0;
    if (!m_clock.isValid()) m_clock.start();
    if (seconds > 0 && rx >= m_rx && tx >= m_tx && m_rx > 0) {
        m_down = (rx - m_rx) / seconds; m_up = (tx - m_tx) / seconds;
        m_downHistory.removeFirst(); m_downHistory.append(m_down);
        m_upHistory.removeFirst(); m_upHistory.append(m_up);
    }
    m_rx = rx; m_tx = tx;
    emit ratesChanged();
#endif
}

void NetworkClient::refreshConnection() {
#ifdef Q_OS_WIN
    // Interface da melhor rota: nome (SSID no Wi-Fi), tipo, IPv4 e sinal. Sem rota, tudo é limpo.
    QElapsedTimer timer; timer.start();
    const auto c = NetworkInfoWin::primary();
    bool dirty = false;
    auto set = [&dirty](auto &field, const auto &value) { if (field != value) { field = value; dirty = true; } };
    set(m_name, c.name); set(m_type, c.type); set(m_address, c.address);
    set(m_strength, c.strength); set(m_hint, c.hint);
    if (!c.valid) { set(m_online, false); set(m_latency, -1); }
    const bool switched = c.luid != m_primaryLuid && m_primaryLuid != 0;
    m_primaryLuid = c.luid;
    if (dirty) emit changed();
    if (switched) measureLatency();
    qCInfo(lcNetwork) << "conexão principal:" << (c.valid ? "sim" : "não") << "Wi-Fi bloqueado:"
                      << !c.hint.isEmpty() << "em" << timer.elapsed() << "ms";
#else
    QString address;
    for (const auto &iface : QNetworkInterface::allInterfaces()) {
        if (!(iface.flags() & QNetworkInterface::IsUp) || !(iface.flags() & QNetworkInterface::IsRunning) || iface.flags() & QNetworkInterface::IsLoopBack) continue;
        if (!countedInterface(iface.name())) continue;
        for (const auto &entry : iface.addressEntries()) {
            if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol) { address = entry.ip().toString(); break; }
        }
        if (!address.isEmpty()) break;
    }
    if (address != m_address) { m_address = address; emit changed(); }
#ifdef QT_DBUS_LIB
    nmProperty(this, "/org/freedesktop/NetworkManager", NM, "PrimaryConnection", [this](const QVariant &value) {
        const QString path = value.value<QDBusObjectPath>().path();
        if (path.isEmpty() || path == "/") {
            if (!m_name.isEmpty()) { m_name.clear(); m_type.clear(); m_strength = -1; emit changed(); }
            return;
        }
        const QString active = NM + ".Connection.Active";
        nmProperty(this, path, active, "Id", [this](const QVariant &id) { if (id.toString() != m_name) { m_name = id.toString(); emit changed(); } });
        nmProperty(this, path, active, "Type", [this, path, active](const QVariant &type) {
            const QString raw = type.toString();
            const QString label = raw.contains("wireless") ? "Wi-Fi" : raw.contains("ethernet") ? "Cabo" : raw.contains("vpn") || raw.contains("wireguard") ? "VPN" : raw.contains("gsm") ? "Móvel" : "Rede";
            if (label != m_type) { m_type = label; emit changed(); }
            if (label != "Wi-Fi") { if (m_strength != -1) { m_strength = -1; emit changed(); } return; }
            nmProperty(this, path, active, "Devices", [this](const QVariant &devices) {
                const auto arg = devices.value<QDBusArgument>();
                QList<QDBusObjectPath> paths; if (arg.currentType() != QDBusArgument::UnknownType) arg >> paths;
                if (paths.isEmpty()) return;
                nmProperty(this, paths.first().path(), NM + ".Device.Wireless", "ActiveAccessPoint", [this](const QVariant &ap) {
                    const QString apPath = ap.value<QDBusObjectPath>().path();
                    if (apPath.isEmpty() || apPath == "/") return;
                    nmProperty(this, apPath, NM + ".AccessPoint", "Strength", [this](const QVariant &strength) {
                        const int value = strength.toInt();
                        if (value != m_strength) { m_strength = value; emit changed(); }
                    });
                });
            });
        });
    });
#endif
#endif
}

void NetworkClient::measureLatency() {
    // Tempo de abertura de uma conexão TCP: não depende de ICMP nem de permissões.
    auto *socket = new QTcpSocket(this);
    auto *timer = new QElapsedTimer; timer->start();
    auto finish = [this, socket, timer](int value) {
        socket->disconnect(this); socket->abort(); socket->deleteLater(); delete timer;
        const bool online = value >= 0;
        if (value != m_latency || online != m_online) { m_latency = value; m_online = online; emit changed(); }
    };
    // Algumas redes bloqueiam IPs diretos (1.1.1.1, 8.8.8.8): usa um nome e mede só a conexão, sem o DNS.
    connect(socket, &QTcpSocket::hostFound, this, [timer] { timer->restart(); });
    connect(socket, &QTcpSocket::connected, this, [finish, timer] { finish(int(timer->elapsed())); });
    connect(socket, &QTcpSocket::errorOccurred, this, [finish] { finish(-1); });
    QTimer::singleShot(4000, socket, [socket, finish] { if (socket->state() != QAbstractSocket::ConnectedState) finish(-1); });
    socket->connectToHost(QStringLiteral("www.google.com"), 443);
}
