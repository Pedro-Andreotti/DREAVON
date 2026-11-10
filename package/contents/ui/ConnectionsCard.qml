import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Card {
    id: card
    required property var dash
    title: "Dispositivos"
    icon: "battery-good-symbolic"
    function iconFor(device) {
        const kind = (device.kind || "").toLowerCase(), name = (device.name || "").toLowerCase()
        if (kind === "mouse" || name.indexOf("mouse") >= 0) return "input-mouse"
        if (kind === "teclado" || name.indexOf("keyboard") >= 0) return "input-keyboard"
        if (kind === "fone") return "audio-headphones"
        if (kind === "celular") return "smartphone"
        if (device.percent >= 0 && !device.kind) return "computer-laptop"
        return "preferences-system-bluetooth"
    }
    // Só aparecem dispositivos que informam bateria; os demais viram uma linha de resumo.
    readonly property var withBattery: dash.peripheralDevices.filter(d => d.percent >= 0)
    readonly property var withoutBattery: dash.peripheralDevices.filter(d => !(d.percent >= 0))
    Text { visible: card.withBattery.length === 0; text: "Nenhum dispositivo informa bateria"; color: card.t.faint; font.pixelSize: 12 }
    Repeater {
        model: card.withBattery
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 8
            Kirigami.Icon { source: card.iconFor(modelData); implicitWidth: 16; implicitHeight: 16; isMask: true; color: card.t.levelColor(modelData.percent) }
            Text { text: modelData.name; color: card.t.ink; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            Rectangle {
                visible: modelData.percent >= 0
                Layout.preferredWidth: 46; height: 5; radius: 3; color: card.t.border
                Rectangle { width: parent.width * Math.max(0, Math.min(100, modelData.percent)) / 100; height: parent.height; radius: 3; color: card.t.levelColor(modelData.percent) }
            }
            Text { text: modelData.percent >= 0 ? Math.round(modelData.percent) + "%" : "—"; color: card.t.muted; font.pixelSize: 11; Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight }
        }
    }
    Text {
        visible: card.withoutBattery.length > 0
        text: card.withoutBattery.length + (card.withoutBattery.length === 1 ? " dispositivo sem bateria informada" : " dispositivos sem bateria informada")
        color: card.t.faint; font.pixelSize: 11
        HoverHandler { id: moreHover }
        ToolTipText { visible: moreHover.hovered; t: card.t; text: card.withoutBattery.map(d => d.name).join(", ") }
    }
}
