import QtQuick
import QtQuick.Effects
import "IconNames.js" as IconNames

// Kirigami.Icon simplificado: aceita um nome do tema (procurado em icons/) ou uma URL.
// isMask pinta o ícone inteiro com a cor de "color", como nos ícones simbólicos do Kirigami.
Item {
    id: icon
    property var source
    property color color: "#e8eaf0"
    property bool isMask: false
    property string fallback: ""
    readonly property bool valid: resolved.toString() !== ""

    implicitWidth: 22
    implicitHeight: 22

    function urlFor(name) {
        const s = String(name || "")
        if (s === "") return ""
        if (s.indexOf(":") >= 0 || s.startsWith("/")) return s
        if (IconNames.names[s]) return Qt.resolvedUrl("icons/" + s + ".svg")
        return ""
    }
    readonly property url resolved: urlFor(source) || urlFor(fallback)

    Image {
        id: image
        anchors.fill: parent
        source: icon.resolved
        sourceSize.width: Math.max(16, icon.width) * 2
        sourceSize.height: Math.max(16, icon.height) * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: !icon.isMask
    }
    MultiEffect {
        anchors.fill: image
        source: image
        visible: icon.isMask && icon.valid
        colorization: 1
        colorizationColor: icon.color
        brightness: 1
    }
}
