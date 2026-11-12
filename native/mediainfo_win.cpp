// Cabeçalhos C++/WinRT primeiro (vêm do Windows SDK, pasta cppwinrt), depois os do Qt.
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/Windows.Storage.Streams.h>

#include "mediainfo_win.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QLoggingCategory>
#include <QMetaObject>
#include <QPointer>
#include <QThreadPool>

#include <functional>
#include <mutex>

#include <windows.h>

// Diagnóstico da mídia no Windows, desligado por padrão (QT_LOGGING_RULES="dreavon.media.info=true").
// Só contagens e durações: nunca título, artista, álbum nem identificadores.
Q_LOGGING_CATEGORY(lcMedia, "dreavon.media", QtWarningMsg)

using namespace winrt::Windows::Media::Control;
namespace wf = winrt::Windows::Foundation;
namespace ws = winrt::Windows::Storage::Streams;
using SmtcManager = GlobalSystemMediaTransportControlsSessionManager;
using SmtcSession = GlobalSystemMediaTransportControlsSession;

namespace MediaInfoWin {

namespace {

constexpr quint64 MaxThumbnailBytes = 5 * 1024 * 1024;

QString qs(const winrt::hstring &s) { return QString::fromWCharArray(s.c_str(), int(s.size())); }

double seconds(wf::TimeSpan span) { return span.count() / 1e7; }

// DateTime do WinRT (intervalos de 100 ns desde 1601) -> ms desde 1970.
qint64 epochMs(wf::DateTime time) {
    const quint64 ticks = winrt::clock::to_file_time(time).value;
    if (ticks < 116444736000000000ULL) return 0;
    return qint64((ticks - 116444736000000000ULL) / 10000);
}

// As threads do QThreadPool não têm apartamento COM; o C++/WinRT precisa de um (MTA aqui, onde
// esperar uma operação assíncrona com get() é permitido; na thread da interface, que é STA, não é).
void ensureApartment() {
    thread_local bool done = false;
    if (done) return;
    done = true;
    try { winrt::init_apartment(winrt::apartment_type::multi_threaded); } catch (...) {}
}

}

void appLabel(const QString &appId, QString *name, QString *entry) {
    const QString id = appId.toLower();
    struct Known { const char *key; const char *label; };
    static const Known known[] = {
        {"spotify", "Spotify"}, {"chrome", "Chrome"}, {"msedge", "Edge"}, {"firefox", "Firefox"},
        {"opera", "Opera"}, {"brave", "Brave"}, {"vivaldi", "Vivaldi"}, {"vlc", "VLC"},
        {"zunemusic", "Media Player"}, {"foobar2000", "foobar2000"}, {"aimp", "AIMP"}, {"itunes", "iTunes"},
    };
    for (const auto &k : known) {
        if (id.contains(QLatin1String(k.key))) { *name = QString::fromLatin1(k.label); *entry = QString::fromLatin1(k.key); return; }
    }
    // Genérico: "Fabricante.App_hash!Id" -> "App"; "programa.exe" -> "programa".
    QString base = appId.section('!', 0, 0).section('_', 0, 0);
    if (base.endsWith(QLatin1String(".exe"), Qt::CaseInsensitive)) base.chop(4);
    base = base.section('.', -1);
    if (base.isEmpty()) base = QStringLiteral("Player");
    *entry = base.toLower();
    base[0] = base[0].toUpper();
    *name = base;
}

bool spotifyProtocolRegistered() {
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CLASSES_ROOT, L"spotify\\shell\\open\\command", 0, KEY_READ, &key) != ERROR_SUCCESS) {
        // Versão da Microsoft Store: o protocolo fica registrado sem a subchave de comando.
        if (RegOpenKeyExW(HKEY_CLASSES_ROOT, L"spotify", 0, KEY_READ, &key) != ERROR_SUCCESS) return false;
    }
    RegCloseKey(key);
    return true;
}

// Estado compartilhado entre a thread da interface, as threads de trabalho e os eventos do SMTC
// (que chegam em threads do sistema). Protegido por mutex; o Session pode ser destruído a qualquer hora.
struct SessionImpl : std::enable_shared_from_this<SessionImpl> {
    std::mutex mutex;
    Session *owner = nullptr;
    SmtcManager manager{nullptr};
    SmtcSession session{nullptr};
    SmtcManager::CurrentSessionChanged_revoker currentRevoker;
    SmtcManager::SessionsChanged_revoker sessionsRevoker;
    SmtcSession::MediaPropertiesChanged_revoker mediaRevoker;
    SmtcSession::PlaybackInfoChanged_revoker playbackRevoker;
    SmtcSession::TimelinePropertiesChanged_revoker timelineRevoker;
    bool running = false, again = false;
    QString lastThumbKey;
    bool lastThumbOk = false;
    int events = 0;

    // Roda f numa thread de trabalho com apartamento MTA, guardando o estado vivo.
    void run(std::function<void(SessionImpl &)> f) {
        auto self = shared_from_this();
        QThreadPool::globalInstance()->start([self, f] {
            ensureApartment();
            try { f(*self); } catch (const winrt::hresult_error &e) {
                qCInfo(lcMedia) << "SMTC: falha" << Qt::hex << quint32(e.code());
            } catch (...) {
                qCInfo(lcMedia) << "SMTC: falha desconhecida";
            }
        });
    }

    // Pede uma nova leitura; eventos seguidos são juntados numa só.
    void requestRefresh() {
        {
            std::lock_guard lock(mutex);
            ++events;
            if (running) { again = true; return; }
            running = true;
        }
        run([](SessionImpl &d) {
            for (;;) {
                // Uma falha (ex.: o app fechou no meio da leitura) não pode travar as próximas leituras.
                try { d.refresh(); } catch (const winrt::hresult_error &e) {
                    qCInfo(lcMedia) << "SMTC: leitura falhou" << Qt::hex << quint32(e.code());
                } catch (...) {
                    qCInfo(lcMedia) << "SMTC: leitura falhou";
                }
                std::lock_guard lock(d.mutex);
                if (!d.again) { d.running = false; return; }
                d.again = false;
            }
        });
    }

    SmtcSession pick() {
        SmtcSession current = manager.GetCurrentSession();
        if (current) return current;
        // Sem sessão "atual": a primeira que estiver tocando, senão a primeira aberta.
        SmtcSession first{nullptr};
        for (const auto &s : manager.GetSessions()) {
            if (!first) first = s;
            const auto info = s.GetPlaybackInfo();
            if (info && info.PlaybackStatus() == GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing) return s;
        }
        return first;
    }

    void subscribe(const SmtcSession &s) {
        std::weak_ptr<SessionImpl> weak = weak_from_this();
        auto poke = [weak](auto &&, auto &&) { if (auto d = weak.lock()) d->requestRefresh(); };
        mediaRevoker = {}; playbackRevoker = {}; timelineRevoker = {};
        { std::lock_guard lock(mutex); session = s; }
        if (!s) return;
        mediaRevoker = s.MediaPropertiesChanged(winrt::auto_revoke, poke);
        playbackRevoker = s.PlaybackInfoChanged(winrt::auto_revoke, poke);
        timelineRevoker = s.TimelinePropertiesChanged(winrt::auto_revoke, poke);
    }

    void refresh() {
        QElapsedTimer timer; timer.start();
        if (!manager) {
            manager = SmtcManager::RequestAsync().get();
            std::weak_ptr<SessionImpl> weak = weak_from_this();
            auto poke = [weak](auto &&, auto &&) { if (auto d = weak.lock()) d->requestRefresh(); };
            currentRevoker = manager.CurrentSessionChanged(winrt::auto_revoke, poke);
            sessionsRevoker = manager.SessionsChanged(winrt::auto_revoke, poke);
        }
        const SmtcSession s = pick();
        if (s != session) subscribe(s);

        Snapshot snap;
        if (s) {
            snap.live = true;
            snap.appId = qs(s.SourceAppUserModelId());
            if (const auto info = s.GetPlaybackInfo()) {
                using St = GlobalSystemMediaTransportControlsSessionPlaybackStatus;
                switch (info.PlaybackStatus()) {
                case St::Playing: snap.status = QStringLiteral("Playing"); break;
                case St::Paused: snap.status = QStringLiteral("Paused"); break;
                case St::Stopped: case St::Opened: case St::Closed: snap.status = QStringLiteral("Stopped"); break;
                default: break;   // Changing: mantém o anterior
                }
                const auto c = info.Controls();
                snap.canPlayPause = c.IsPlayPauseToggleEnabled() || c.IsPlayEnabled() || c.IsPauseEnabled();
                snap.canNext = c.IsNextEnabled();
                snap.canPrevious = c.IsPreviousEnabled();
                snap.canSeek = c.IsPlaybackPositionEnabled();
                if (const auto shuffle = info.IsShuffleActive(); shuffle && c.IsShuffleEnabled()) {
                    snap.hasShuffle = true; snap.shuffle = shuffle.Value();
                }
                if (const auto repeat = info.AutoRepeatMode(); repeat && c.IsRepeatEnabled()) {
                    using R = winrt::Windows::Media::MediaPlaybackAutoRepeatMode;
                    snap.loop = repeat.Value() == R::Track ? QStringLiteral("Track")
                              : repeat.Value() == R::List ? QStringLiteral("Playlist") : QStringLiteral("None");
                }
            }
            if (const auto tl = s.GetTimelineProperties()) {
                const double start = seconds(tl.StartTime());
                snap.length = qMax(0.0, seconds(tl.EndTime()) - start);
                snap.position = qMax(0.0, seconds(tl.Position()) - start);
                snap.positionAt = epochMs(tl.LastUpdatedTime());
                const qint64 now = QDateTime::currentMSecsSinceEpoch();
                if (snap.positionAt <= 0 || snap.positionAt > now) snap.positionAt = now;
                if (snap.length <= 0) snap.canSeek = false;
            }
            if (const auto props = s.TryGetMediaPropertiesAsync().get()) {
                snap.title = qs(props.Title());
                snap.artist = qs(props.Artist());
                snap.album = qs(props.AlbumTitle());
                // A capa vem como stream; só é lida quando a música muda (ou se ainda não veio).
                const QString key = snap.appId + QChar(1) + snap.title + QChar(1) + snap.artist + QChar(1) + snap.album;
                if (key != lastThumbKey || !lastThumbOk) {
                    lastThumbKey = key; lastThumbOk = false;
                    if (const auto ref = props.Thumbnail()) {
                        const auto stream = ref.OpenReadAsync().get();
                        const quint64 size = stream.Size();
                        if (size > 0 && size <= MaxThumbnailBytes) {
                            ws::Buffer buffer{static_cast<uint32_t>(size)};
                            const auto read = stream.ReadAsync(buffer, quint32(size), ws::InputStreamOptions::None).get();
                            QByteArray bytes(int(read.Length()), Qt::Uninitialized);
                            ws::DataReader::FromBuffer(read).ReadBytes(winrt::array_view<uint8_t>(
                                reinterpret_cast<uint8_t *>(bytes.data()), reinterpret_cast<uint8_t *>(bytes.data()) + bytes.size()));
                            if (!bytes.isEmpty()) { snap.thumbnail = bytes; snap.thumbKey = key; lastThumbOk = true; }
                        }
                    }
                }
            }
        }

        int count = 0;
        {
            std::lock_guard lock(mutex);
            count = events; events = 0;
            if (owner) {
                QPointer<Session> target(owner);
                QMetaObject::invokeMethod(owner, [target, snap] {
                    if (!target) return;
                    target->m_snapshot = snap;
                    emit target->changed();
                }, Qt::QueuedConnection);
            }
        }
        qCInfo(lcMedia) << "SMTC: leitura em" << timer.elapsed() << "ms; eventos juntados:" << count
                        << "sessão:" << snap.live << "capa (bytes):" << snap.thumbnail.size();
    }

    // Executa um controle na sessão atual, fora da thread da interface, e mede o tempo de resposta.
    void control(const char *what, std::function<wf::IAsyncOperation<bool>(const SmtcSession &)> op) {
        run([what, op](SessionImpl &d) {
            SmtcSession s{nullptr};
            { std::lock_guard lock(d.mutex); s = d.session; }
            if (!s) return;
            QElapsedTimer timer; timer.start();
            const bool ok = op(s).get();
            qCInfo(lcMedia) << "SMTC:" << what << (ok ? "aceito" : "recusado") << "em" << timer.elapsed() << "ms";
            d.requestRefresh();
        });
    }
};

Session::Session(QObject *parent) : QObject(parent), d(std::make_shared<SessionImpl>()) {
    d->owner = this;
    d->requestRefresh();
}

Session::~Session() {
    // As inscrições nos eventos saem junto com o estado compartilhado, quando a última leitura em
    // andamento terminar; daqui em diante nenhum resultado é entregue.
    std::lock_guard lock(d->mutex);
    d->owner = nullptr;
}

void Session::playPause() { d->control("play/pause", [](const SmtcSession &s) { return s.TryTogglePlayPauseAsync(); }); }
void Session::play() { d->control("play", [](const SmtcSession &s) { return s.TryPlayAsync(); }); }
void Session::next() { d->control("próxima", [](const SmtcSession &s) { return s.TrySkipNextAsync(); }); }
void Session::previous() { d->control("anterior", [](const SmtcSession &s) { return s.TrySkipPreviousAsync(); }); }

void Session::seek(double secondsValue) {
    d->control("posição", [secondsValue](const SmtcSession &s) {
        // A posição é absoluta, a partir do StartTime da linha do tempo, em intervalos de 100 ns.
        const auto tl = s.GetTimelineProperties();
        const qint64 start = tl ? tl.StartTime().count() : 0;
        return s.TryChangePlaybackPositionAsync(start + qint64(secondsValue * 1e7));
    });
}

void Session::setShuffle(bool on) {
    d->control("aleatório", [on](const SmtcSession &s) { return s.TryChangeShuffleActiveAsync(on); });
}

void Session::setLoop(const QString &mode) {
    using R = winrt::Windows::Media::MediaPlaybackAutoRepeatMode;
    const R value = mode == QLatin1String("Track") ? R::Track : mode == QLatin1String("Playlist") ? R::List : R::None;
    d->control("repetir", [value](const SmtcSession &s) { return s.TryChangeAutoRepeatModeAsync(value); });
}

}
