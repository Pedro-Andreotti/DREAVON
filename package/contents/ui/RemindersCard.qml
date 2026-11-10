import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B
import org.kde.kirigami as Kirigami

// Lista de lembretes salva nas configurações do widget (texto JSON).
Card {
    id: card
    property string stored: "[]"
    signal save(string json)
    title: "Lembretes"
    icon: "view-task-symbolic"
    property var items: { try { const v = JSON.parse(stored); return Array.isArray(v) ? v : [] } catch (e) { return [] } }
    readonly property int pending: items.filter(i => !i.done).length
    function commit(list) { save(JSON.stringify(list)) }
    function add(text) {
        const value = text.trim(); if (!value) return
        commit(items.concat([{id: Date.now().toString(36), text: value, done: false}]))
    }
    function toggle(id) { commit(items.map(i => i.id === id ? Object.assign({}, i, {done: !i.done}) : i)) }
    function remove(id) { commit(items.filter(i => i.id !== id)) }

    actions: [
        IconButton { t: card.t; icon: "edit-clear-all-symbolic"; tip: "Limpar concluídos"; size: 22; visible: card.items.length > card.pending; onClicked: card.commit(card.items.filter(i => !i.done)) }
    ]

    Repeater {
        model: card.items
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true; height: Math.max(28, label.implicitHeight + 10); radius: 8
            color: rowHover.hovered ? card.t.cardRaised : "transparent"
            HoverHandler { id: rowHover }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 2; spacing: 8
                Rectangle {
                    width: 16; height: 16; radius: 8
                    color: modelData.done ? card.t.accent : "transparent"
                    border.color: modelData.done ? card.t.accent : card.t.faint; border.width: 1.5
                    Kirigami.Icon { anchors.centerIn: parent; visible: modelData.done; source: "checkmark"; width: 11; height: 11; isMask: true; color: "#101119" }
                    TapHandler { onTapped: card.toggle(modelData.id) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Text {
                    id: label; text: modelData.text; Layout.fillWidth: true; wrapMode: Text.Wrap
                    color: modelData.done ? card.t.faint : card.t.ink; font.pixelSize: 12; font.strikeout: modelData.done
                }
                IconButton { t: card.t; icon: "edit-delete-remove"; tip: "Remover"; size: 20; opacity: rowHover.hovered ? 1 : 0; onClicked: card.remove(modelData.id) }
            }
        }
    }
    B.TextField {
        id: input
        Layout.fillWidth: true
        placeholderText: card.items.length ? "Novo lembrete…" : "Anote algo para não esquecer…"
        placeholderTextColor: card.t.faint
        color: card.t.ink; font.pixelSize: 12
        leftPadding: 10; topPadding: 6; bottomPadding: 6
        background: Rectangle { radius: 8; color: card.t.cardRaised; border.color: input.activeFocus ? card.t.accentLine : "transparent" }
        onAccepted: { card.add(text); text = "" }
    }
}
