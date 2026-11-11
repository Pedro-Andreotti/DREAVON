import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
    id: page
    property string cfg_accentColor
    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_animations: animations.checked

    readonly property var accentChoices: [
        {color: "#2f8bff", name: "DREAVON (azul elétrico)"}, {color: "#2bd9b0", name: "Verde-água"}, {color: "#8b7cff", name: "Violeta"},
        {color: "#5fd38a", name: "Verde"}, {color: "#f2b64c", name: "Âmbar"}, {color: "#ff7a6b", name: "Coral"},
        {color: "#ff6fb5", name: "Rosa"}, {color: "#c7cbd6", name: "Grafite"}
    ]

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: "Cor de destaque:"
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: page.accentChoices
                delegate: Rectangle {
                    required property var modelData
                    width: Kirigami.Units.gridUnit * 1.6; height: width; radius: width / 2
                    color: modelData.color
                    border.width: page.cfg_accentColor.toLowerCase() === modelData.color ? 3 : 0
                    border.color: Kirigami.Theme.textColor
                    QQC2.ToolTip.visible: hover.hovered; QQC2.ToolTip.text: modelData.name
                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: page.cfg_accentColor = modelData.color }
                }
            }
        }
        RowLayout {
            Kirigami.FormData.label: "Opacidade do fundo:"
            QQC2.Slider { id: opacitySlider; from: 60; to: 100; stepSize: 1; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
            QQC2.Label { text: Math.round(opacitySlider.value) + "%" }
        }
        QQC2.CheckBox { id: animations; Kirigami.FormData.label: "Movimento:"; text: "Animações (ícones do clima, transições)" }
    }
}
