import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// Ícone do painel: anel com a cota de 5 horas restante e pulso enquanto o Claude responde.
Item {
    id: icon
    required property var t
    required property var client
    signal clicked()
    readonly property real free: client.fiveHourUsed < 0 ? -1 : 100 - client.fiveHourUsed
    implicitWidth: 24; implicitHeight: 24

    Ring {
        anchors.fill: parent
        anchors.margins: Math.max(1, parent.height * 0.06)
        value: icon.free < 0 ? 100 : icon.free
        color: icon.free < 0 ? icon.t.accent : icon.t.levelColor(icon.free)
        track: Qt.rgba(1, 1, 1, 0.15)
        thickness: Math.max(2, parent.height * 0.1)
        label: ""
        duration: 0
    }
    // Marca monocromática, na cor do texto do tema do painel (claro ou escuro).
    Image {
        id: mark
        anchors.centerIn: parent
        height: Math.max(9, parent.height * 0.5); width: height * 133 / 158
        source: "assets/mark-mono.png"; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1; colorizationColor: Kirigami.Theme.textColor; brightness: 1 }
        SequentialAnimation on opacity {
            running: icon.client.busy; loops: Animation.Infinite
            onRunningChanged: if (!running) parent.opacity = 1
            NumberAnimation { to: 0.3; duration: 500 }
            NumberAnimation { to: 1; duration: 500 }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: icon.clicked() }
}
