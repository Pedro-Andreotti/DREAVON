#include "hotkey_win.h"

#include <QLoggingCategory>
#include <QStringList>

#include <windows.h>

// Diagnóstico do atalho global, desligado por padrão (QT_LOGGING_RULES="dreavon.hotkey.info=true").
// Só resultados (aceito/recusado, código de erro) e contagens; nunca o que foi digitado.
Q_LOGGING_CATEGORY(lcHotkey, "dreavon.hotkey", QtWarningMsg)

namespace HotkeyWin {

namespace {
constexpr int HotkeyId = 0xD7E1;
constexpr int ProbeId = 0xD7E2;
const wchar_t *ClassName = L"DreavonHotkeyWindow";

LRESULT CALLBACK windowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
    if (message == WM_HOTKEY && wParam == WPARAM(HotkeyId)) {
        if (auto *self = reinterpret_cast<Registration *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA))) {
            static int count = 0;
            qCInfo(lcHotkey) << "atalho acionado; vezes nesta sessão:" << ++count;
            self->activate();
        }
        return 0;
    }
    return DefWindowProcW(hwnd, message, wParam, lParam);
}

HWND createWindow() {
    static bool registered = false;
    if (!registered) {
        WNDCLASSW wc = {};
        wc.lpfnWndProc = windowProc;
        wc.hInstance = GetModuleHandleW(nullptr);
        wc.lpszClassName = ClassName;
        registered = RegisterClassW(&wc) != 0 || GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
    }
    return CreateWindowExW(0, ClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), nullptr);
}
}

bool parse(const QString &sequence, unsigned *modifiers, unsigned *virtualKey) {
    const QStringList parts = sequence.split('+', Qt::SkipEmptyParts);
    if (parts.size() < 2) return false;
    unsigned mods = 0, vk = 0;
    for (int i = 0; i < parts.size(); ++i) {
        const QString p = parts[i].trimmed().toLower();
        if (i < parts.size() - 1) {
            if (p == QLatin1String("ctrl") || p == QLatin1String("control")) mods |= MOD_CONTROL;
            else if (p == QLatin1String("alt")) mods |= MOD_ALT;
            else if (p == QLatin1String("shift")) mods |= MOD_SHIFT;
            else if (p == QLatin1String("win") || p == QLatin1String("meta")) mods |= MOD_WIN;
            else return false;
            continue;
        }
        if (p.size() == 1 && p[0].isLetterOrNumber() && p[0].unicode() < 128) vk = p[0].toUpper().unicode();
        else if (p == QLatin1String("espaço") || p == QLatin1String("space")) vk = VK_SPACE;
        else if (p.startsWith('f')) {
            bool ok = false;
            const int n = p.mid(1).toInt(&ok);
            if (ok && n >= 1 && n <= 24) vk = VK_F1 + unsigned(n - 1);
        }
    }
    // Só Shift não basta: atrapalharia a digitação em todos os apps.
    if (!vk || !(mods & (MOD_CONTROL | MOD_ALT | MOD_WIN))) return false;
    *modifiers = mods;
    *virtualKey = vk;
    return true;
}

Registration::Registration(std::function<void()> onActivated) : m_onActivated(std::move(onActivated)) {
    HWND hwnd = createWindow();
    if (hwnd) SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
    m_window = hwnd;
}

Registration::~Registration() {
    clear();
    if (m_window) DestroyWindow(static_cast<HWND>(m_window));
}

void Registration::clear() {
    if (m_active && m_window) UnregisterHotKey(static_cast<HWND>(m_window), HotkeyId);
    m_active = false;
}

int Registration::set(const QString &sequence) {
    clear();
    unsigned mods = 0, vk = 0;
    if (!parse(sequence, &mods, &vk)) return -1;
    if (!m_window) return int(ERROR_INVALID_WINDOW_HANDLE);
    // MOD_NOREPEAT: segurar as teclas não repete a ação.
    if (!RegisterHotKey(static_cast<HWND>(m_window), HotkeyId, mods | MOD_NOREPEAT, vk)) {
        const int error = int(GetLastError());
        qCInfo(lcHotkey) << "registro recusado; erro" << error;
        return error ? error : -1;
    }
    m_active = true;
    qCInfo(lcHotkey) << "registro aceito";
    return 0;
}

int Registration::probe(const QString &sequence) {
    unsigned mods = 0, vk = 0;
    if (!parse(sequence, &mods, &vk)) return -1;
    if (!RegisterHotKey(nullptr, ProbeId, mods | MOD_NOREPEAT, vk)) return int(GetLastError());
    UnregisterHotKey(nullptr, ProbeId);
    return 0;
}

}
