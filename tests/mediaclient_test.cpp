#include <QtTest>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusObjectPath>
#include <QImage>

#include "../native/mediaclient.h"

// Um "Spotify" falso no D-Bus da sessão de teste (rodar com dbus-run-session).
class FakePlayer : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus MEMBER status)
    Q_PROPERTY(QVariantMap Metadata MEMBER metadata)
    Q_PROPERTY(qlonglong Position MEMBER position)
    Q_PROPERTY(bool CanGoNext MEMBER yes)
    Q_PROPERTY(bool CanGoPrevious MEMBER yes)
    Q_PROPERTY(bool CanSeek MEMBER yes)
    Q_PROPERTY(bool Shuffle MEMBER shuffle)
    Q_PROPERTY(QString LoopStatus MEMBER loop)
    Q_PROPERTY(double Volume MEMBER volume)
public:
    QString status = "Playing", loop = "None";
    QVariantMap metadata;
    qlonglong position = 0;
    bool yes = true, shuffle = false;
    double volume = 0.8;
    QStringList calls;
    void setTrack(const QString &id, const QString &title, const QString &art) {
        metadata = {{"mpris:trackid", QVariant::fromValue(QDBusObjectPath("/com/spotify/track/" + id))},
                    {"xesam:title", title}, {"xesam:artist", QStringList{"Artista"}}, {"xesam:album", "Álbum"},
                    {"mpris:length", qlonglong(200'000'000)}, {"mpris:artUrl", art},
                    {"xesam:url", "https://open.spotify.com/track/" + id}};
    }
public slots:
    void PlayPause() { calls << "PlayPause"; status = status == "Playing" ? "Paused" : "Playing"; }
    void Play() { calls << "Play"; status = "Playing"; }
    void OpenUri(const QString &uri) { calls << "OpenUri " + uri; }
    void SetPosition(const QDBusObjectPath &track, qlonglong at) { calls << QString("SetPosition %1 %2").arg(track.path()).arg(at / 1000000); position = at; }
};

class MediaClientTest : public QObject {
    Q_OBJECT
    QTemporaryDir m_home;
    QString m_art;
    FakePlayer m_player;
    const QString Service = "org.mpris.MediaPlayer2.spotify";

    void publish() {
        auto bus = QDBusConnection::sessionBus();
        QVERIFY(bus.registerObject("/org/mpris/MediaPlayer2", &m_player, QDBusConnection::ExportAllContents));
        QVERIFY(bus.registerService(Service));
    }
    void unpublish() {
        auto bus = QDBusConnection::sessionBus();
        bus.unregisterService(Service);
        bus.unregisterObject("/org/mpris/MediaPlayer2");
    }

private slots:
    void initTestCase() {
        QVERIFY(QDBusConnection::sessionBus().isConnected());
        qputenv("XDG_DATA_HOME", (m_home.path() + "/data").toUtf8());
        qputenv("XDG_CACHE_HOME", (m_home.path() + "/cache").toUtf8());
        qputenv("DREAVON_SPOTIFY_COMMAND", "true");   // "abrir o Spotify" não faz nada no teste
        m_art = m_home.path() + "/capa.png";
        QImage image(8, 8, QImage::Format_RGB32); image.fill(Qt::green);
        QVERIFY(image.save(m_art));
    }

    void remembersTrackAfterPlayerCloses() {
        m_player.setTrack("ABC123", "Música de teste", QUrl::fromLocalFile(m_art).toString());
        m_player.position = 42'000'000;
        publish();
        MediaClient client;
        QTRY_VERIFY_WITH_TIMEOUT(client.live() && client.title() == "Música de teste", 5000);
        QCOMPARE(client.artist(), QString("Artista"));
        QVERIFY(client.isSpotify());
        QCOMPARE(client.volume(), 0.8);
        QCOMPARE(client.loopStatus(), QString("None"));
        // A capa vira uma cópia local, que sobrevive ao arquivo original.
        QTRY_VERIFY(client.artUrl().isLocalFile() && client.artUrl().toLocalFile().contains("/cache/dreavon/art/"));

        m_player.status = "Paused";
        QTest::qWait(1700);
        unpublish();
        QFile::remove(m_art);
        QTRY_VERIFY_WITH_TIMEOUT(!client.live(), 5000);
        QVERIFY(client.available());
        QVERIFY(!client.playing());
        QCOMPARE(client.title(), QString("Música de teste"));
        QVERIFY(QFileInfo::exists(client.artUrl().toLocalFile()));
        QVERIFY(qAbs(client.position() - 42) < 3);

        // Um widget novo (ex.: Plasma reiniciado) ainda lembra a música, sem player nem internet.
        MediaClient again;
        QVERIFY(again.available());
        QVERIFY(!again.live());
        QCOMPARE(again.title(), QString("Música de teste"));
        QVERIFY(QFileInfo::exists(again.artUrl().toLocalFile()));
    }

    void resumesWhereItStopped() {
        MediaClient client;
        QVERIFY(!client.live());
        QCOMPARE(client.title(), QString("Música de teste"));
        m_player.calls.clear();
        m_player.metadata.clear();
        m_player.status = "Stopped";
        m_player.position = 0;

        client.playPause();          // abre o "Spotify"
        QVERIFY(client.launching());
        publish();                   // o Spotify aparece no D-Bus, ainda sem música
        QTRY_VERIFY_WITH_TIMEOUT(m_player.calls.contains("OpenUri spotify:track:ABC123"), 8000);
        m_player.setTrack("ABC123", "Música de teste", "");
        m_player.status = "Playing";
        QTRY_VERIFY_WITH_TIMEOUT(m_player.calls.contains("SetPosition /com/spotify/track/ABC123 42"), 8000);
        QTRY_VERIFY_WITH_TIMEOUT(!client.launching() && client.live() && client.playing(), 5000);
        unpublish();
    }

    void forgetClearsRememberedTrack() {
        MediaClient client;
        QTRY_VERIFY_WITH_TIMEOUT(!client.live(), 5000);
        QVERIFY(client.available());
        client.forget();
        QVERIFY(!client.available());
        MediaClient again;
        QVERIFY(!again.available());
    }
};

QTEST_GUILESS_MAIN(MediaClientTest)
#include "mediaclient_test.moc"
