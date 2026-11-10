import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Card {
    id: card
    required property var net
    title: "Rede"
    stretch: true
    icon: "network-wireless-symbolic"
    readonly property string signalIcon: {
        const s = net.signalStrength
        if (net.connectionType === "Cabo") return "network-wired"
        if (s < 0) return net.online ? "network-wireless" : "network-wireless-disconnected"
        return s >= 75 ? "network-wireless-signal-excellent" : s >= 50 ? "network-wireless-signal-good" : s >= 25 ? "network-wireless-signal-ok" : "network-wireless-signal-weak"
    }

    RowLayout {
        spacing: 8; Layout.fillWidth: true
        Kirigami.Icon { source: card.signalIcon; implicitWidth: 20; implicitHeight: 20; isMask: true; color: card.net.online ? card.t.accent : card.t.bad }
        ColumnLayout {
            spacing: 0; Layout.fillWidth: true
            Text { text: card.net.connectionName || (card.net.online ? "Conectado" : "Sem conexão"); color: card.t.ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Text {
                text: [card.net.connectionType, card.net.signalStrength >= 0 ? "sinal " + card.net.signalStrength + "%" : "", card.net.localAddress].filter(Boolean).join(" · ")
                color: card.t.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
            }
        }
        Rectangle {
            radius: 9; height: 18; width: latency.implicitWidth + 14
            color: Qt.rgba(pingColor.r, pingColor.g, pingColor.b, 0.15)
            readonly property color pingColor: !card.net.online ? card.t.bad : card.net.latency < 80 ? card.t.good : card.net.latency < 200 ? card.t.warn : card.t.bad
            Text { id: latency; anchors.centerIn: parent; text: card.net.online ? card.net.latency + " ms" : "offline"; color: parent.pingColor; font.pixelSize: 10; font.weight: Font.DemiBold }
        }
    }
    Sparkline {
        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 42; Layout.preferredHeight: 42
        values: card.net.downloadHistory; secondary: card.net.uploadHistory
        color: card.t.accent; secondaryColor: card.t.good
    }
    RowLayout {
        Layout.fillWidth: true
        Text { text: "↓ " + card.net.formatRate(card.net.downloadRate); color: card.t.accent; font.pixelSize: 12; font.weight: Font.Medium }
        Item { Layout.fillWidth: true }
        Text { text: "↑ " + card.net.formatRate(card.net.uploadRate); color: card.t.good; font.pixelSize: 12; font.weight: Font.Medium }
    }
}
