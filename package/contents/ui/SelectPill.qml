import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B
import org.kde.kirigami as Kirigami

// Seletor compacto em formato de pílula que abre uma lista.
Rectangle {
    id: pill
    required property var t
    property var options: []       // [{value, text}]
    property string value
    property string tip
    signal picked(string value)
    readonly property string currentText: {
        for (let i = 0; i < options.length; ++i) if (options[i].value === value) return options[i].text
        return value || "—"
    }
    implicitWidth: row.implicitWidth + 16; implicitHeight: 24
    Layout.minimumWidth: 44
    radius: 12
    color: hover.hovered || menu.opened ? t.cardRaised : "transparent"
    border.color: t.border
    opacity: enabled ? 1 : 0.4
    RowLayout {
        id: row; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 4
        Text { text: pill.currentText; color: pill.t.ink; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.alignment: Qt.AlignVCenter }
        Kirigami.Icon { source: "arrow-down"; implicitWidth: 10; implicitHeight: 10; isMask: true; color: pill.t.muted; Layout.alignment: Qt.AlignVCenter }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: menu.opened ? menu.close() : menu.open() }
    B.ToolTip.visible: hover.hovered && !menu.opened && tip !== ""
    B.ToolTip.text: tip
    B.ToolTip.delay: 500

    B.Popup {
        id: menu
        y: pill.height + 4
        padding: 4
        width: Math.max(pill.width, 150)
        background: Rectangle { color: pill.t.cardRaised; radius: 10; border.color: pill.t.border }
        contentItem: Column {
            Repeater {
                model: pill.options
                delegate: Rectangle {
                    required property var modelData
                    width: menu.width - 8; height: 28; radius: 7
                    color: itemHover.hovered ? pill.t.accentSoft : "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter; x: 10
                        text: modelData.text; font.pixelSize: 12
                        color: modelData.value === pill.value ? pill.t.accent : pill.t.ink
                        font.weight: modelData.value === pill.value ? Font.DemiBold : Font.Normal
                    }
                    HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { menu.close(); pill.picked(modelData.value) } }
                }
            }
        }
    }
}
