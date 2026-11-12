#pragma once

// Atalho global no Windows (passo 7a) por RegisterHotKey. O WM_HOTKEY chega a uma janela só de
// mensagens (HWND_MESSAGE) própria, e não à fila da thread: mensagens da thread se perdem enquanto o
// Windows roda um laço modal (arrastar ou redimensionar a janela, menu aberto).

#include <QString>
#include <functional>

namespace HotkeyWin {

// "Ctrl+Shift+Alt+D" -> modificadores MOD_* e tecla virtual. Exige Ctrl, Alt ou Win e uma tecla:
// letra, número, F1–F24 ou Espaço. Falso se a combinação não for aceita.
bool parse(const QString &sequence, unsigned *modifiers, unsigned *virtualKey);

class Registration {
public:
    explicit Registration(std::function<void()> onActivated);
    ~Registration();   // desregistra e destrói a janela
    Registration(const Registration &) = delete;
    Registration &operator=(const Registration &) = delete;

    // 0 = registrado; senão, o erro do Windows (ex.: 1409, combinação já em uso) ou -1 (inválida).
    int set(const QString &sequence);
    void clear();
    bool active() const { return m_active; }

    // Testa uma combinação sem ficar com ela: registra com outro id e desregistra na hora.
    static int probe(const QString &sequence);

    void activate() { if (m_onActivated) m_onActivated(); }   // chamado pela janela de mensagens

private:
    std::function<void()> m_onActivated;
    void *m_window = nullptr;
    bool m_active = false;
};

}
