import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

// Conversas salvas (Antigravity, Claude, Codex), com busca e importação. Fecha ao escolher uma.
Rectangle {
    id: overlay
    required property var t
    required property var client
    property bool opened: false
    visible: opacity > 0
    opacity: opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: overlay.t.duration } }
    color: overlay.t.card
    radius: overlay.t.radius
    border.color: overlay.t.border
    function open() { opened = true; client.refreshHistory(); search.forceActiveFocus() }
    function close() { opened = false; search.text = "" }
    Keys.onEscapePressed: close()
    Connections { target: overlay.client; function onConversationLoaded() { overlay.close() } }
    readonly property var filtered: {
        const q = search.text.trim().toLocaleLowerCase()
        return client.history.filter(c => !q || [c.title, c.preview, c.cwd, c.source].join(" ").toLocaleLowerCase().indexOf(q) >= 0)
    }
    function when(seconds) {
        if (!seconds) return ""
        const d = new Date(seconds * 1000), now = new Date()
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, "HH:mm") : Qt.formatDate(d, "dd/MM")
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: wheel => wheel.accepted = true }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        RowLayout {
            Text { text: "Conversas · " + overlay.client.providerName; color: overlay.t.ink; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
            IconButton { t: overlay.t; icon: "document-open"; tip: "Importar conversa de arquivo"; onClicked: importDialog.open() }
            IconButton { t: overlay.t; icon: "view-refresh"; tip: "Atualizar"; onClicked: overlay.client.refreshHistory() }
            IconButton { t: overlay.t; icon: "window-close"; tip: "Fechar"; onClicked: overlay.close() }
        }
        B.TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Buscar por título, conteúdo ou pasta"
            placeholderTextColor: overlay.t.faint; color: overlay.t.ink; font.pixelSize: 12
            leftPadding: 10; topPadding: 7; bottomPadding: 7
            background: Rectangle { radius: 9; color: overlay.t.cardRaised; border.color: search.activeFocus ? overlay.t.accentLine : "transparent" }
        }
        Text { visible: overlay.client.historyError !== ""; text: overlay.client.historyError; color: overlay.t.bad; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 2
            model: overlay.filtered
            B.ScrollBar.vertical: B.ScrollBar { policy: B.ScrollBar.AsNeeded }
            delegate: Rectangle {
                required property var modelData
                width: list.width - 8; height: 50; radius: 9
                color: itemHover.hovered ? overlay.t.cardRaised : "transparent"
                HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: overlay.client.loadConversation(modelData.id) }
                ColumnLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 1
                    RowLayout {
                        Text { text: modelData.title; color: modelData.id === overlay.client.threadId ? overlay.t.accent : overlay.t.ink; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText }
                        Text { text: overlay.when(modelData.updatedAt); color: overlay.t.faint; font.pixelSize: 10 }
                    }
                    RowLayout {
                        Rectangle {
                            radius: 4; height: 14; width: sourceLabel.implicitWidth + 8; color: overlay.t.accentSoft
                            Text { id: sourceLabel; anchors.centerIn: parent; text: modelData.source; color: overlay.t.accent; font.pixelSize: 9; font.weight: Font.DemiBold }
                        }
                        Text { text: modelData.preview; color: overlay.t.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; maximumLineCount: 1 }
                    }
                }
            }
            footer: Item {
                width: list.width; height: overlay.client.historyHasMore ? 38 : 0; visible: overlay.client.historyHasMore
                Text {
                    anchors.centerIn: parent; text: overlay.client.historyBusy ? "Carregando…" : "Carregar mais conversas"; color: overlay.t.accent; font.pixelSize: 12
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: overlay.client.loadMoreHistory() }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: overlay.client.historyBusy ? "Carregando conversas…" : "Nenhuma conversa encontrada"
                color: overlay.t.faint; font.pixelSize: 12
            }
        }
    }

    FileDialog {
        id: importDialog
        title: "Importar conversa (.jsonl, .json, .md)"
        fileMode: FileDialog.OpenFile
        onAccepted: overlay.client.importConversation(selectedFile)
    }
}
