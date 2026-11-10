import QtQuick
import QtQuick.Layouts

Card {
    id: card
    required property var dash
    title: "Sistema"
    icon: "computer-symbolic"
    function gib(used, total) { return used < 0 || total <= 0 ? "" : used.toFixed(1) + "/" + Math.round(total) + " GiB" }

    GridLayout {
        columns: 4; columnSpacing: 4; rowSpacing: 0
        Layout.fillWidth: true
        Repeater {
            model: [
                {name: "CPU", value: card.dash.cpuUsage, detail: ""},
                {name: "GPU", value: card.dash.gpuUsage, detail: ""},
                {name: "RAM", value: card.dash.memoryUsage, detail: card.gib(card.dash.memoryUsedGiB, card.dash.memoryTotalGiB)},
                {name: "Disco", value: card.dash.storageUsage, detail: card.gib(card.dash.storageUsedGiB, card.dash.storageTotalGiB)}
            ]
            delegate: Ring {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 66
                value: modelData.value; caption: modelData.name
                color: card.t.usageColor(modelData.value); track: card.t.border
                ink: card.t.ink; mutedInk: card.t.muted; duration: card.t.animations ? 500 : 0
                thickness: 4.5
                HoverHandler { id: tipHover }
                ToolTipText { visible: tipHover.hovered && modelData.detail !== ""; text: modelData.detail; t: card.t }
            }
        }
    }
}
