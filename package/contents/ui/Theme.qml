import QtQuick

// Paleta e medidas compartilhadas por todos os cartões.
QtObject {
    property color accent: "#3daee9"
    property real backgroundOpacity: 0.94
    property bool animations: true

    readonly property color background: Qt.rgba(0.075, 0.08, 0.105, backgroundOpacity)
    readonly property color card: "#1b1d27"
    readonly property color cardRaised: "#232634"
    readonly property color border: "#2c2f3d"
    readonly property color ink: "#eceef5"
    readonly property color muted: "#9ba1b5"
    readonly property color faint: "#646a80"
    readonly property color good: "#5fd38a"
    readonly property color warn: "#f2b64c"
    readonly property color bad: "#ff6b6b"
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
    readonly property color accentLine: Qt.rgba(accent.r, accent.g, accent.b, 0.45)

    readonly property int radius: 14
    readonly property int gap: 10
    readonly property int pad: 14
    readonly property int duration: animations ? 180 : 0

    // Uso: verde até 70%, âmbar até 90%, vermelho acima.
    function usageColor(used) { return used < 0 ? faint : used < 70 ? good : used < 90 ? warn : bad }
    // Carga restante (bateria, cota): vermelho até 20%, âmbar até 40%.
    function levelColor(left) { return left < 0 ? faint : left <= 20 ? bad : left <= 40 ? warn : good }
}
