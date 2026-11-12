#include "globalhotkey.h"

#ifdef Q_OS_WIN
#include "hotkey_win.h"
#include <QTimer>
#endif

GlobalHotkey::GlobalHotkey(QObject *parent) : QObject(parent) {
#ifdef Q_OS_WIN
    // O aviso chega pela janela de mensagens; repassa na volta do laço de eventos, fora do WndProc.
    m_registration = std::make_unique<HotkeyWin::Registration>([this] {
        QTimer::singleShot(0, this, [this] { emit activated(); });
    });
#endif
}

// Desregistra ao fechar o app (o destrutor da Registration chama UnregisterHotKey).
GlobalHotkey::~GlobalHotkey() = default;

bool GlobalHotkey::supported() const {
#ifdef Q_OS_WIN
    return true;
#else
    return false;
#endif
}

bool GlobalHotkey::registered() const {
#ifdef Q_OS_WIN
    return m_registration && m_registration->active();
#else
    return false;
#endif
}

void GlobalHotkey::setSequence(const QString &sequence) {
    const QString value = sequence.trimmed();
    if (value == m_sequence) return;
    m_sequence = value;
    apply();
}

void GlobalHotkey::setPaused(bool paused) {
    if (paused == m_paused) return;
    m_paused = paused;
    apply();
}

QString GlobalHotkey::describe(int error) {
    if (error == 0) return {};
    if (error == -1) return QStringLiteral("Combinação inválida: use Ctrl, Alt ou Win com uma letra, um número, F1–F24 ou Espaço.");
    if (error == 1409) return QStringLiteral("Em uso por outro aplicativo: o Windows recusou este atalho. Escolha outra combinação.");
    return QStringLiteral("O Windows recusou o atalho (erro %1).").arg(error);
}

void GlobalHotkey::apply() {
#ifdef Q_OS_WIN
    int error = 0;
    // Trocar de atalho ou pausar desregistra o anterior antes de qualquer coisa.
    if (m_paused || m_sequence.isEmpty()) m_registration->clear();
    else error = m_registration->set(m_sequence);
    m_status = describe(error);
#endif
    emit changed();
}

QString GlobalHotkey::check(const QString &sequence) const {
#ifdef Q_OS_WIN
    const QString value = sequence.trimmed();
    if (value.isEmpty()) return {};
    // A combinação que o próprio DREAVON já usa aparece como "em uso" para o Windows.
    if (value == m_sequence && registered()) return {};
    return describe(HotkeyWin::Registration::probe(value));
#else
    Q_UNUSED(sequence);
    return {};
#endif
}
