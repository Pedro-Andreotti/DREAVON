#include "mediaclient.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <memory>

namespace {
const QString Prefix = QStringLiteral("org.mpris.MediaPlayer2.");
const QString PlayerPath = QStringLiteral("/org/mpris/MediaPlayer2");
const QString PlayerInterface = QStringLiteral("org.mpris.MediaPlayer2.Player");
const QString PropsInterface = QStringLiteral("org.freedesktop.DBus.Properties");
constexpr int MaxCachedArt = 150;
constexpr qint64 ResumeTimeoutMs = 30000;

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

QString objectPath(const QVariant &value) {
    const QVariant inner = plain(value);
    if (inner.canConvert<QDBusObjectPath>()) return inner.value<QDBusObjectPath>().path();
    return inner.toString();
}

// "org.mpris.MediaPlayer2.firefox.instance_1_23" -> "firefox"
QString entryOf(const QString &service) { return service.mid(Prefix.size()).section('.', 0, 0).toLower(); }

// Endereço que o Spotify sabe abrir: spotify:track:<id>.
QString spotifyUri(const QString &trackId, const QString &url) {
    static const QString TrackPath = QStringLiteral("/com/spotify/track/");
    if (trackId.startsWith(TrackPath)) return "spotify:track:" + trackId.mid(TrackPath.size());
    const QUrl u(url);
    if (u.host() == QLatin1String("open.spotify.com")) {
        const QStringList parts = u.path().split('/', Qt::SkipEmptyParts);
        if (parts.size() >= 2) return "spotify:" + parts[0] + ':' + parts[1];
    }
    return {};
}
}

MediaClient::MediaClient(QObject *parent) : QObject(parent), m_net(new QNetworkAccessManager(this)) {
    restore();
    m_timer.setInterval(1500);
    connect(&m_timer, &QTimer::timeout, this, &MediaClient::poll);
    m_timer.start();
    // A posição é extrapolada localmente entre as consultas, para a barra andar suave.
    m_tick.setInterval(500);
    connect(&m_tick, &QTimer::timeout, this, [this] { if (playing()) emit positionChanged(); });
    m_tick.start();
    poll();
}

QUrl MediaClient::artUrl() const {
    if (!m_artFile.isEmpty() && QFileInfo::exists(m_artFile)) return QUrl::fromLocalFile(m_artFile);
    return live() ? m_artUrl : QUrl();
}

bool MediaClient::spotifyInstalled() const { return !QStandardPaths::findExecutable(spotifyCommand()).isEmpty(); }

QString MediaClient::spotifyCommand() const {
    const QString custom = qEnvironmentVariable("PLASDRIA_SPOTIFY_COMMAND");
    return custom.isEmpty() ? QStringLiteral("spotify") : custom;
}

double MediaClient::position() const {
    double value = m_position;
    if (playing() && m_positionAt > 0) value += (QDateTime::currentMSecsSinceEpoch() - m_positionAt) / 1000.0;
    return m_length > 0 ? qMin(value, m_length) : value;
}

void MediaClient::poll() {
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface()) return;
    if (m_pendingResume && QDateTime::currentMSecsSinceEpoch() - m_resumeSince > ResumeTimeoutMs) {
        m_pendingResume = false; emit changed();
    }
    const QStringList services = bus.interface()->registeredServiceNames().value().filter(Prefix);
    if (services.isEmpty()) { playerGone(); return; }
    auto results = std::make_shared<QHash<QString, QVariantMap>>();
    auto remaining = std::make_shared<int>(services.size());
    for (const QString &service : services) {
        auto msg = QDBusMessage::createMethodCall(service, PlayerPath, PropsInterface, "GetAll");
        msg << PlayerInterface;
        auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(msg, 1200), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, results, remaining, services, service](QDBusPendingCallWatcher *w) {
            QDBusPendingReply<QVariantMap> reply = *w; w->deleteLater();
            if (!reply.isError()) results->insert(service, reply.value());
            if (--*remaining > 0) return;
            auto has = [&](const QString &s) { return results->contains(s); };
            auto statusOf = [&](const QString &s) { return plain(results->value(s).value("PlaybackStatus")).toString(); };
            // Ordem: o player que estamos abrindo > o que está tocando > o atual > Spotify > o primeiro.
            QString chosen;
            if (m_pendingResume) for (const auto &s : services) if (has(s) && entryOf(s) == m_entry) { chosen = s; break; }
            if (chosen.isEmpty()) for (const auto &s : services) if (has(s) && statusOf(s) == "Playing") { chosen = s; break; }
            if (chosen.isEmpty() && has(m_service)) chosen = m_service;
            if (chosen.isEmpty()) for (const auto &s : services) if (has(s) && entryOf(s) == "spotify") { chosen = s; break; }
            if (chosen.isEmpty()) for (const auto &s : services) if (has(s)) { chosen = s; break; }
            if (chosen.isEmpty()) { playerGone(); return; }
            apply(chosen, results->value(chosen));
        });
    }
}

void MediaClient::apply(const QString &service, const QVariantMap &p) {
    const auto meta = metadataMap(p.value("Metadata"));
    const QString title = plain(meta.value("xesam:title")).toString();
    const QString trackId = objectPath(meta.value("mpris:trackid"));
    const QString entry = entryOf(service);

    QString name = service.mid(Prefix.size()).section('.', 0, 0);
    if (!name.isEmpty()) name[0] = name[0].toUpper();

    // Retomando a última música: o player acabou de abrir.
    if (m_pendingResume && entry == m_entry) {
        if (!m_resumeOpened) {
            m_resumeOpened = true;
            const QString target = service;
            // O Spotify precisa de um instante depois de aparecer no D-Bus.
            QTimer::singleShot(1500, this, [this, target] { resumeOn(target); });
            return;
        }
        const bool sameTrack = (!m_trackId.isEmpty() && trackId == m_trackId) || (!title.isEmpty() && title == m_title);
        if (!sameTrack && QDateTime::currentMSecsSinceEpoch() - m_resumeSince < ResumeTimeoutMs) return;
        m_pendingResume = false;
        if (sameTrack && m_position > 3 && (m_length <= 0 || m_position < m_length - 3) && !trackId.isEmpty()) {
            auto msg = QDBusMessage::createMethodCall(service, PlayerPath, PlayerInterface, "SetPosition");
            msg << QVariant::fromValue(QDBusObjectPath(trackId)) << QVariant::fromValue<qlonglong>(qlonglong(m_position * 1e6));
            QDBusConnection::sessionBus().asyncCall(msg, 1500);
        }
    }

    m_service = service;
    m_status = plain(p.value("PlaybackStatus")).toString();
    m_canNext = plain(p.value("CanGoNext")).toBool();
    m_canPrevious = plain(p.value("CanGoPrevious")).toBool();
    m_hasShuffle = p.contains("Shuffle");
    m_shuffle = plain(p.value("Shuffle")).toBool();
    m_loop = plain(p.value("LoopStatus")).toString();
    m_volume = p.contains("Volume") ? qBound(0.0, plain(p.value("Volume")).toDouble(), 1.0) : -1;

    // Player aberto sem música carregada (ex.: Spotify recém-aberto): mantém a lembrada.
    if (title.isEmpty() && !m_title.isEmpty() && entry == m_entry) {
        m_canSeek = false;
        emit changed(); emit positionChanged();
        return;
    }

    const bool newTrack = trackId + title != m_trackId + m_title;
    m_player = name;
    m_entry = entry;
    m_title = title;
    m_artist = joined(meta.value("xesam:artist"));
    m_album = plain(meta.value("xesam:album")).toString();
    m_trackId = trackId;
    m_uri = spotifyUri(trackId, plain(meta.value("xesam:url")).toString());
    m_length = plain(meta.value("mpris:length")).toLongLong() / 1e6;
    m_position = plain(p.value("Position")).toLongLong() / 1e6;
    m_positionAt = QDateTime::currentMSecsSinceEpoch();
    m_canSeek = plain(p.value("CanSeek")).toBool() && m_length > 0;
    const QUrl art(plain(meta.value("mpris:artUrl")).toString());
    if (newTrack || art != m_artUrl) {
        m_artUrl = art;
        m_artFile.clear();
        cacheArt();
    }
    save();
    emit changed(); emit positionChanged();
}

void MediaClient::playerGone() {
    if (m_service.isEmpty()) return;
    m_position = position();
    m_positionAt = 0;
    m_service.clear();
    m_status = "Paused";
    save();
    emit changed(); emit positionChanged();
}

// Guarda uma cópia da capa: ela continua aparecendo sem internet ou com o player fechado.
void MediaClient::cacheArt() {
    if (m_artUrl.isEmpty()) return;
    const QString key = QString::fromLatin1(QCryptographicHash::hash(m_artUrl.toString().toUtf8(), QCryptographicHash::Sha1).toHex());
    QDir().mkpath(artDir());
    const QString file = artDir() + '/' + key;
    if (QFileInfo::exists(file)) { m_artFile = file; return; }

    auto prune = [this] {
        QDir dir(artDir());
        const auto files = dir.entryInfoList(QDir::Files, QDir::Time);   // mais novas primeiro
        for (int i = MaxCachedArt; i < files.size(); ++i) QFile::remove(files[i].filePath());
    };
    if (m_artUrl.isLocalFile()) {
        // Navegadores apagam a capa temporária quando a aba fecha.
        if (QFile::copy(m_artUrl.toLocalFile(), file)) { m_artFile = file; prune(); }
        return;
    }
    if (m_artUrl.scheme() != QLatin1String("http") && m_artUrl.scheme() != QLatin1String("https")) return;
    if (m_artLoading == file) return;
    m_artLoading = file;
    QNetworkRequest request(m_artUrl);
    request.setTransferTimeout(10000);
    QNetworkReply *reply = m_net->get(request);
    const QUrl source = m_artUrl;
    connect(reply, &QNetworkReply::finished, this, [this, reply, file, source, prune] {
        reply->deleteLater();
        if (m_artLoading == file) m_artLoading.clear();
        const QByteArray data = reply->readAll();
        if (reply->error() != QNetworkReply::NoError || data.isEmpty() || data.size() > 5 * 1024 * 1024) return;
        QSaveFile out(file);
        if (!out.open(QIODevice::WriteOnly) || out.write(data) != data.size() || !out.commit()) return;
        prune();
        if (m_artUrl == source) { m_artFile = file; save(); emit changed(); }
    });
}

QString MediaClient::statePath() const {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/plasdria/media.json";
}

QString MediaClient::artDir() const {
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + "/plasdria/art";
}

void MediaClient::save() {
    if (m_title.isEmpty()) return;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const QString key = m_trackId + m_title + m_status + m_artFile + (m_service.isEmpty() ? "off" : "on");
    if (key == m_savedKey && (!playing() || now - m_savedAt < 10000)) return;
    m_savedKey = key; m_savedAt = now;
    const QJsonObject state{
        {"player", m_player}, {"entry", m_entry}, {"title", m_title}, {"artist", m_artist}, {"album", m_album},
        {"trackId", m_trackId}, {"uri", m_uri}, {"art", m_artUrl.toString()}, {"artFile", m_artFile},
        {"length", m_length}, {"position", position()}, {"savedAt", now}};
    QDir().mkpath(QFileInfo(statePath()).absolutePath());
    QSaveFile out(statePath());
    if (!out.open(QIODevice::WriteOnly)) return;
    out.write(QJsonDocument(state).toJson(QJsonDocument::Compact));
    out.commit();
    QFile::setPermissions(statePath(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

void MediaClient::restore() {
    QFile in(statePath());
    if (!in.open(QIODevice::ReadOnly)) return;
    const QJsonObject s = QJsonDocument::fromJson(in.readAll()).object();
    m_player = s["player"].toString();
    m_entry = s["entry"].toString();
    m_title = s["title"].toString();
    m_artist = s["artist"].toString();
    m_album = s["album"].toString();
    m_trackId = s["trackId"].toString();
    m_uri = s["uri"].toString();
    m_artUrl = QUrl(s["art"].toString());
    m_artFile = s["artFile"].toString();
    m_length = s["length"].toDouble();
    m_position = s["position"].toDouble();
    m_status = "Paused";
}

void MediaClient::forget() {
    QFile::remove(statePath());
    if (live()) return;
    m_title.clear(); m_artist.clear(); m_album.clear(); m_trackId.clear(); m_uri.clear();
    m_artUrl.clear(); m_artFile.clear(); m_length = m_position = 0; m_savedKey.clear();
    emit changed(); emit positionChanged();
}

void MediaClient::launch(const QString &entry) {
    const QString command = entry == QLatin1String("spotify") || entry.isEmpty() ? spotifyCommand() : entry;
    if (QStandardPaths::findExecutable(command).isEmpty()) return;
    QProcess::startDetached(command, {});
}

void MediaClient::resumeOn(const QString &service) {
    QString method = "Play";
    QVariantList args;
    if (entryOf(service) == "spotify" && !m_uri.isEmpty()) { method = "OpenUri"; args << m_uri; }
    auto msg = QDBusMessage::createMethodCall(service, PlayerPath, PlayerInterface, method);
    msg.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(msg, 3000);
    QTimer::singleShot(400, this, &MediaClient::poll);
}

void MediaClient::call(const QString &method, const QVariantList &args) {
    if (m_service.isEmpty()) return;
    auto msg = QDBusMessage::createMethodCall(m_service, PlayerPath, PlayerInterface, method);
    msg.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(msg, 1500);
    QTimer::singleShot(250, this, &MediaClient::poll);
}

void MediaClient::setPlayerProperty(const QString &name, const QVariant &value) {
    if (m_service.isEmpty()) return;
    auto msg = QDBusMessage::createMethodCall(m_service, PlayerPath, PropsInterface, "Set");
    msg << PlayerInterface << name << QVariant::fromValue(QDBusVariant(value));
    QDBusConnection::sessionBus().asyncCall(msg, 1500);
    QTimer::singleShot(250, this, &MediaClient::poll);
}

void MediaClient::playPause() {
    if (!live()) {
        // Player fechado: abre e retoma a última música do ponto em que parou.
        if (m_pendingResume) return;
        m_pendingResume = true; m_resumeOpened = false;
        m_resumeSince = QDateTime::currentMSecsSinceEpoch();
        if (m_entry.isEmpty()) m_entry = "spotify";
        launch(m_entry);
        emit changed();
        return;
    }
    // Player aberto, mas ainda sem música: toca a lembrada.
    if (m_status.isEmpty() || m_status == QLatin1String("Stopped")) {
        if (isSpotify() && !m_uri.isEmpty()) {
            m_pendingResume = true; m_resumeOpened = true;
            m_resumeSince = QDateTime::currentMSecsSinceEpoch();
            resumeOn(m_service);
            emit changed();
            return;
        }
    }
    // Atualiza na hora para a interface responder sem esperar o player.
    m_position = position(); m_positionAt = QDateTime::currentMSecsSinceEpoch();
    m_status = playing() ? "Paused" : "Playing";
    emit changed();
    call("PlayPause");
}
void MediaClient::next() { call("Next"); }
void MediaClient::previous() { call("Previous"); }
void MediaClient::seek(double seconds) {
    if (!canSeek()) return;
    const double delta = seconds - position();
    m_position = seconds; m_positionAt = QDateTime::currentMSecsSinceEpoch(); emit positionChanged();
    call("Seek", {QVariant::fromValue<qlonglong>(qlonglong(delta * 1e6))});
}
void MediaClient::raise() {
    if (m_service.isEmpty()) { launch(m_entry); return; }
    QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(m_service, PlayerPath, "org.mpris.MediaPlayer2", "Raise"), 1500);
}
void MediaClient::setShuffle(bool on) { m_shuffle = on; emit changed(); setPlayerProperty("Shuffle", on); }
void MediaClient::cycleLoop() {
    m_loop = m_loop == QLatin1String("None") ? "Playlist" : m_loop == QLatin1String("Playlist") ? "Track" : "None";
    emit changed();
    setPlayerProperty("LoopStatus", m_loop);
}
void MediaClient::setVolume(double value) { m_volume = qBound(0.0, value, 1.0); emit changed(); setPlayerProperty("Volume", m_volume); }
void MediaClient::openSpotify() {
    for (const QString &s : QDBusConnection::sessionBus().interface()->registeredServiceNames().value().filter(Prefix + "spotify")) {
        QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(s, PlayerPath, "org.mpris.MediaPlayer2", "Raise"), 1500);
        return;
    }
    launch("spotify");
}
