import QtQuick

// Dica pequena posicionada acima do item pai.
Rectangle {
    required property var t
    property alias text: label.text
    z: 50
    width: label.implicitWidth + 12; height: label.implicitHeight + 8; radius: 6
    color: t.cardRaised; border.color: t.border
    anchors.bottom: parent.top; anchors.horizontalCenter: parent.horizontalCenter
    Text { id: label; anchors.centerIn: parent; color: parent.t.ink; font.pixelSize: 10 }
}
