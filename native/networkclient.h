#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QElapsedTimer>

// Velocidade de rede, conexão ativa (NetworkManager), IP local e latência.
class NetworkClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(double downloadRate READ downloadRate NOTIFY ratesChanged)
    Q_PROPERTY(double uploadRate READ uploadRate NOTIFY ratesChanged)
    Q_PROPERTY(QVariantList downloadHistory READ downloadHistory NOTIFY ratesChanged)
    Q_PROPERTY(QVariantList uploadHistory READ uploadHistory NOTIFY ratesChanged)
    Q_PROPERTY(QString connectionName READ connectionName NOTIFY changed)
    Q_PROPERTY(QString connectionType READ connectionType NOTIFY changed)
    Q_PROPERTY(int signalStrength READ signalStrength NOTIFY changed)
    Q_PROPERTY(QString localAddress READ localAddress NOTIFY changed)
    Q_PROPERTY(int latency READ latency NOTIFY changed)
    Q_PROPERTY(bool online READ online NOTIFY changed)
public:
    explicit NetworkClient(QObject *parent = nullptr);
    double downloadRate() const { return m_down; }
    double uploadRate() const { return m_up; }
    QVariantList downloadHistory() const { return m_downHistory; }
    QVariantList uploadHistory() const { return m_upHistory; }
    QString connectionName() const { return m_name; }
    QString connectionType() const { return m_type; }
    int signalStrength() const { return m_strength; }
    QString localAddress() const { return m_address; }
    int latency() const { return m_latency; }
    bool online() const { return m_online; }
    Q_INVOKABLE static QString formatRate(double bytesPerSecond);

signals:
    void ratesChanged();
    void changed();

private:
    void sampleRates();
    void refreshConnection();
    void measureLatency();
    QTimer m_rateTimer, m_connectionTimer, m_latencyTimer;
    QElapsedTimer m_clock;
    quint64 m_rx = 0, m_tx = 0;
    double m_down = 0, m_up = 0;
    QVariantList m_downHistory, m_upHistory;
    QString m_name, m_type, m_address;
    int m_strength = -1, m_latency = -1;
    bool m_online = false;
};
