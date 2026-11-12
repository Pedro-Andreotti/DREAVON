#pragma once

// Sessão de mídia do Windows (SMTC: GlobalSystemMediaTransportControlsSessionManager) para o MediaClient
// (passo 6), por C++/WinRT do próprio Windows SDK. Os tipos WinRT ficam só no .cpp.
// Tudo é por eventos: o gerenciador avisa troca de sessão e a sessão avisa mudança de música, de estado
// e de posição. As chamadas ao SMTC rodam fora da thread da interface e o resultado volta por changed().

#include <QByteArray>
#include <QObject>
#include <QString>
#include <memory>

namespace MediaInfoWin {

struct Snapshot {
    bool live = false;          // há uma sessão de mídia aberta
    QString appId;              // AppUserModelId do app (ex.: "Spotify.exe", "Chrome")
    QString status;             // "Playing", "Paused", "Stopped" ou "" (mudando / desconhecido)
    QString title, artist, album;
    double length = 0;          // segundos; 0 se o app não informa
    double position = 0;        // segundos, no instante positionAt
    qint64 positionAt = 0;      // ms desde a época em que o app mediu a posição
    bool canPlayPause = false, canNext = false, canPrevious = false, canSeek = false;
    bool hasShuffle = false, shuffle = false;   // hasShuffle falso: o app não informa
    QString loop;               // "None", "Track", "Playlist" ou "" se o app não informa
    QString thumbKey;           // identifica a música da capa abaixo (vazio = sem capa lida)
    QByteArray thumbnail;       // bytes da capa (imagem), lidos só quando a música muda
};

// Nome amigável e chave curta (minúscula) do app a partir do AppUserModelId.
// Ex.: "SpotifyAB.SpotifyMusic_xxx!Spotify" -> ("Spotify", "spotify"); "Chrome" -> ("Chrome", "chrome").
void appLabel(const QString &appId, QString *name, QString *entry);

// O protocolo spotify: está registrado (Spotify do instalador ou da Microsoft Store).
bool spotifyProtocolRegistered();

class Session : public QObject {
    Q_OBJECT
public:
    explicit Session(QObject *parent = nullptr);
    ~Session() override;
    Snapshot snapshot() const { return m_snapshot; }

    // Controles assíncronos: o app pode recusar; o resultado aparece no próximo changed().
    void playPause();
    void play();
    void next();
    void previous();
    void seek(double seconds);
    void setShuffle(bool on);
    void setLoop(const QString &mode);   // "None", "Track" ou "Playlist"

signals:
    void changed();

private:
    friend struct SessionImpl;
    std::shared_ptr<struct SessionImpl> d;
    Snapshot m_snapshot;
};

}
