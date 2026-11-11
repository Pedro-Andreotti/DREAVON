#pragma once

#include <QObject>
#include <QString>
#include <QUrl>

// Guarda segredos (como a chave da API compatível) no cofre de credenciais do sistema.
// No Windows usa o Gerenciador de Credenciais (CredWrite/CredRead/CredDelete). Em outras
// plataformas "supported" é falso e as funções devolvem falso/vazio com o erro "não suportado".
// Só aceita destinos que começam com "DREAVON/", para o QML não ler outras credenciais.
// Os segredos nunca vão para logs nem para as mensagens de erro.
class CredentialStore : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool supported READ supported CONSTANT)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
public:
    explicit CredentialStore(QObject *parent = nullptr) : QObject(parent) {}

    static bool supported();
    QString lastError() const { return m_lastError; }
    int revision() const { return m_revision; }

    Q_INVOKABLE bool set(const QString &target, const QString &secret);
    Q_INVOKABLE QString get(const QString &target);
    Q_INVOKABLE bool remove(const QString &target);
    Q_INVOKABLE bool exists(const QString &target);
    // Move uma chave em texto puro de um arquivo .ini para o cofre e apaga o valor do arquivo.
    // Devolve verdadeiro se havia uma chave e ela foi migrada.
    Q_INVOKABLE bool migrateFromSettings(const QUrl &iniFile, const QString &key, const QString &target);

    // Leitura direta, para o C++ usar a chave sem passá-la pelo QML.
    static QString read(const QString &target, QString *error = nullptr);

signals:
    void lastErrorChanged();
    void changed();

private:
    static bool validTarget(const QString &target);
    void setError(const QString &error);
    QString m_lastError;
    int m_revision = 0;
};
