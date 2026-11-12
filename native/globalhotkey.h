#pragma once

#include <QObject>
#include <QString>
#include <memory>

#ifdef Q_OS_WIN
namespace HotkeyWin { class Registration; }
#endif

// Atalho global para mostrar/ocultar o painel. No Windows usa RegisterHotKey (hotkey_win.cpp);
// nas outras plataformas não faz nada (supported = false) e o atalho fica com o sistema.
class GlobalHotkey : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString sequence READ sequence WRITE setSequence NOTIFY changed)   // ex.: "Ctrl+Shift+Alt+D"
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY changed)            // solto durante a captura
    Q_PROPERTY(bool registered READ registered NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)                         // vazio = tudo certo
    Q_PROPERTY(bool supported READ supported CONSTANT)
public:
    explicit GlobalHotkey(QObject *parent = nullptr);
    ~GlobalHotkey() override;

    QString sequence() const { return m_sequence; }
    void setSequence(const QString &sequence);
    bool paused() const { return m_paused; }
    void setPaused(bool paused);
    bool registered() const;
    QString status() const { return m_status; }
    bool supported() const;

    // Situação de uma combinação candidata, sem trocar a atual: "" se dá para usar.
    Q_INVOKABLE QString check(const QString &sequence) const;

signals:
    void changed();
    void activated();

private:
    void apply();
    static QString describe(int error);

    QString m_sequence, m_status;
    bool m_paused = false;
#ifdef Q_OS_WIN
    std::unique_ptr<HotkeyWin::Registration> m_registration;
#endif
};
