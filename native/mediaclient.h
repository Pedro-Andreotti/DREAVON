#pragma once

#include <QObject>
#include <QTimer>
#include <QUrl>

// Player de mídia ativo via MPRIS (Spotify, navegadores, VLC, Elisa…).
class MediaClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool playing READ playing NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(QString artist READ artist NOTIFY changed)
    Q_PROPERTY(QString album READ album NOTIFY changed)
    Q_PROPERTY(QUrl artUrl READ artUrl NOTIFY changed)
    Q_PROPERTY(QString player READ player NOTIFY changed)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double length READ length NOTIFY changed)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY changed)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY changed)
    Q_PROPERTY(bool canSeek READ canSeek NOTIFY changed)
public:
    explicit MediaClient(QObject *parent = nullptr);
    bool available() const { return !m_service.isEmpty(); }
    bool playing() const { return m_status == QLatin1String("Playing"); }
    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString album() const { return m_album; }
    QUrl artUrl() const { return m_artUrl; }
    QString player() const { return m_player; }
    double position() const;
    double length() const { return m_length; }
    bool canGoNext() const { return m_canNext; }
    bool canGoPrevious() const { return m_canPrevious; }
    bool canSeek() const { return m_canSeek; }

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void raise();

signals:
    void changed();
    void positionChanged();

private:
    void poll();
    void call(const QString &method, const QVariantList &args = {});
    QTimer m_timer, m_tick;
    QString m_service, m_status, m_title, m_artist, m_album, m_player, m_trackId;
    QUrl m_artUrl;
    double m_length = 0, m_position = 0;
    qint64 m_positionAt = 0;
    bool m_canNext = false, m_canPrevious = false, m_canSeek = false;
};
