import QtQuick

// Dica pequena posicionada acima do item pai.
Rectangle {
    required property var t
    property alias text: label.text
    property real maxWidth: 0   // 0 = sem limite (uma linha); acima disso, o texto quebra
    z: 50
    width: label.width + 12; height: label.height + 8; radius: 6
    color: t.cardRaised; border.color: t.border
    anchors.bottom: parent.top; anchors.horizontalCenter: parent.horizontalCenter
    Text {
        id: label; anchors.centerIn: parent; color: parent.t.ink; font.pixelSize: 10
        width: parent.maxWidth > 0 ? Math.min(implicitWidth, parent.maxWidth) : implicitWidth
        wrapMode: parent.maxWidth > 0 ? Text.Wrap : Text.NoWrap
    }
}
