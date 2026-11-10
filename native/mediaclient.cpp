#include "mediaclient.h"

#include <QDateTime>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusArgument>
#include <QDBusVariant>
#include <memory>

namespace {
const QString Prefix = QStringLiteral("org.mpris.MediaPlayer2.");
const QString PlayerPath = QStringLiteral("/org/mpris/MediaPlayer2");
const QString PlayerInterface = QStringLiteral("org.mpris.MediaPlayer2.Player");

QVariant plain(const QVariant &value) {
    if (value.canConvert<QDBusVariant>()) return value.value<QDBusVariant>().variant();
    return value;
}

QVariantMap metadataMap(const QVariant &value) {
    const QVariant inner = plain(value);
    if (inner.canConvert<QDBusArgument>()) {
        QVariantMap map;
        inner.value<QDBusArgument>() >> map;
        for (auto i = map.begin(); i != map.end(); ++i) i.value() = plain(i.value());
        return map;
    }
    return inner.toMap();
}

QString joined(const QVariant &value) {
    const QVariant inner = plain(value);
    if (inner.canConvert<QDBusArgument>()) { QStringList list; inner.value<QDBusArgument>() >> list; return list.join(", "); }
    if (inner.typeId() == QMetaType::QStringList) return inner.toStringList().join(", ");
    return inner.toString();
}
}

MediaClient::MediaClient(QObject *parent) : QObject(parent) {
    m_timer.setInterval(1500);
    connect(&m_timer, &QTimer::timeout, this, &MediaClient::poll);
    m_timer.start();
    // A posição é extrapolada localmente entre as consultas, para a barra andar suave.
    m_tick.setInterval(500);
    connect(&m_tick, &QTimer::timeout, this, [this] { if (playing()) emit positionChanged(); });
    m_tick.start();
    poll();
}

double MediaClient::position() const {
    double value = m_position;
    if (playing() && m_positionAt > 0) value += (QDateTime::currentMSecsSinceEpoch() - m_positionAt) / 1000.0;
    return m_length > 0 ? qMin(value, m_length) : value;
}

void MediaClient::poll() {
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface()) return;
    const QStringList services = bus.interface()->registeredServiceNames().value().filter(Prefix);
    if (services.isEmpty()) {
        if (!m_service.isEmpty()) { m_service.clear(); m_title.clear(); m_status.clear(); emit changed(); }
        return;
    }
    // Consulta todos e escolhe: o que está tocando > o atual > o primeiro.
    auto results = std::make_shared<QHash<QString, QVariantMap>>();
    auto remaining = std::make_shared<int>(services.size());
    for (const QString &service : services) {
        auto msg = QDBusMessage::createMethodCall(service, PlayerPath, "org.freedesktop.DBus.Properties", "GetAll");
        msg << PlayerInterface;
        auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(msg, 1200), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, service, results, remaining, services](QDBusPendingCallWatcher *w) {
            QDBusPendingReply<QVariantMap> reply = *w; w->deleteLater();
            if (!reply.isError()) results->insert(service, reply.value());
            if (--*remaining > 0) return;
            QString chosen;
            for (const auto &s : services) if (results->contains(s) && plain(results->value(s).value("PlaybackStatus")).toString() == "Playing") { chosen = s; break; }
            if (chosen.isEmpty() && results->contains(m_service)) chosen = m_service;
            if (chosen.isEmpty()) for (const auto &s : services) if (results->contains(s)) { chosen = s; break; }
            if (chosen.isEmpty()) { if (!m_service.isEmpty()) { m_service.clear(); emit changed(); } return; }
            const auto p = results->value(chosen);
            const auto meta = metadataMap(p.value("Metadata"));
            m_service = chosen;
            QString name = chosen.mid(Prefix.size()).section('.', 0, 0);
            if (!name.isEmpty()) name[0] = name[0].toUpper();
            m_player = name;
            m_status = plain(p.value("PlaybackStatus")).toString();
            m_title = plain(meta.value("xesam:title")).toString();
            m_artist = joined(meta.value("xesam:artist"));
            m_album = plain(meta.value("xesam:album")).toString();
            m_artUrl = QUrl(plain(meta.value("mpris:artUrl")).toString());
            m_length = plain(meta.value("mpris:length")).toLongLong() / 1e6;
            const QString track = plain(meta.value("mpris:trackid")).value<QDBusObjectPath>().path() + m_title;
            m_position = plain(p.value("Position")).toLongLong() / 1e6;
            m_positionAt = QDateTime::currentMSecsSinceEpoch();
            m_trackId = track;
            m_canNext = plain(p.value("CanGoNext")).toBool();
            m_canPrevious = plain(p.value("CanGoPrevious")).toBool();
            m_canSeek = plain(p.value("CanSeek")).toBool() && m_length > 0;
            emit changed(); emit positionChanged();
        });
    }
}

void MediaClient::call(const QString &method, const QVariantList &args) {
    if (m_service.isEmpty()) return;
    auto msg = QDBusMessage::createMethodCall(m_service, PlayerPath, PlayerInterface, method);
    msg.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(msg, 1500);
    QTimer::singleShot(250, this, &MediaClient::poll);
}

void MediaClient::playPause() {
    // Atualiza na hora para a interface responder sem esperar o player.
    m_position = position(); m_positionAt = QDateTime::currentMSecsSinceEpoch();
    m_status = playing() ? "Paused" : "Playing";
    emit changed();
    call("PlayPause");
}
void MediaClient::next() { call("Next"); }
void MediaClient::previous() { call("Previous"); }
void MediaClient::seek(double seconds) {
    if (!m_canSeek) return;
    const double delta = seconds - position();
    m_position = seconds; m_positionAt = QDateTime::currentMSecsSinceEpoch(); emit positionChanged();
    call("Seek", {QVariant::fromValue<qlonglong>(qlonglong(delta * 1e6))});
}
void MediaClient::raise() {
    if (m_service.isEmpty()) return;
    QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(m_service, PlayerPath, "org.mpris.MediaPlayer2", "Raise"), 1500);
}
