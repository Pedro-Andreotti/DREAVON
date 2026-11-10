import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Uma mensagem do chat. Respostas do Claude aparecem formatadas (Markdown) e selecionáveis.
Item {
    id: bubble
    required property var t
    required property var client
    required property string speaker
    required property string body
    required property var files
    property int availableWidth: 400
    readonly property bool mine: speaker === "user"
    property bool copied: false
    width: availableWidth
    implicitHeight: column.implicitHeight

    HoverHandler { id: hover }
    Timer { id: copiedReset; interval: 1500; onTriggered: bubble.copied = false }
    function copy() { client.copyText(body); copied = true; copiedReset.restart() }
    // Nas mensagens do usuário, o botão de copiar fica à esquerda do balão.
    IconButton {
        visible: bubble.mine
        t: bubble.t; size: 22; opacity: hover.hovered || bubble.copied ? 1 : 0
        anchors.right: column.left; anchors.rightMargin: 4; anchors.verticalCenter: column.verticalCenter
        icon: bubble.copied ? "checkmark" : "edit-copy"; tip: bubble.copied ? "Copiado" : "Copiar"
        onClicked: bubble.copy()
    }

    ColumnLayout {
        id: column
        width: bubble.mine ? Math.min(bubble.availableWidth * 0.82, Math.max(content.implicitWidth, filesRow.implicitWidth) + 26) : bubble.availableWidth
        anchors.right: bubble.mine ? parent.right : undefined
        spacing: 4

        RowLayout {
            visible: !bubble.mine; spacing: 6
            Image { source: "assets/mark.png"; Layout.preferredHeight: 16; Layout.preferredWidth: 14; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
            Text { text: "Claude"; color: bubble.t.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            IconButton {
                t: bubble.t; size: 22; opacity: hover.hovered || bubble.copied ? 1 : 0
                icon: bubble.copied ? "checkmark" : "edit-copy"; tip: bubble.copied ? "Copiado" : "Copiar resposta"
                onClicked: bubble.copy()
            }
        }
        Flow {
            id: filesRow
            visible: bubble.files && bubble.files.length > 0
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: bubble.files || []
                delegate: Rectangle {
                    required property var modelData
                    height: 26; width: chipRow.implicitWidth + 14; radius: 8; color: bubble.t.cardRaised; border.color: bubble.t.border
                    Row {
                        id: chipRow; anchors.centerIn: parent; spacing: 5
                        Kirigami.Icon { source: modelData.kind === "image" ? "image-x-generic" : "text-x-generic"; width: 14; height: 14; isMask: true; color: bubble.t.muted; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.name; color: bubble.t.ink; font.pixelSize: 11; elide: Text.ElideMiddle; width: Math.min(implicitWidth, 160); anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        Rectangle {
            visible: bubble.body !== ""
            Layout.fillWidth: true
            implicitHeight: content.implicitHeight + (bubble.mine ? 16 : 0)
            radius: 12
            color: bubble.mine ? bubble.t.accentSoft : "transparent"
            border.color: bubble.mine ? bubble.t.accentLine : "transparent"
            TextEdit {
                id: content
                x: bubble.mine ? 12 : 0; y: bubble.mine ? 8 : 0
                width: parent.width - (bubble.mine ? 24 : 0)
                text: bubble.body
                textFormat: bubble.mine ? TextEdit.PlainText : TextEdit.MarkdownText
                readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                color: bubble.t.ink; selectionColor: bubble.t.accentLine; selectedTextColor: bubble.t.ink
                font.pixelSize: 13
                onLinkActivated: link => Qt.openUrlExternally(link)
                HoverHandler { cursorShape: content.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
            }
        }
    }
}
