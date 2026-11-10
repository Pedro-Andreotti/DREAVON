import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B

// Layout principal. Largo: 3 colunas. Médio: barra lateral + chat. Estreito: abas.
Item {
    id: shell
    required property var t
    required property var client
    required property var dash
    required property var media
    required property var net
    required property var cfg
    signal saveReminders(string json)

    readonly property string mode: width >= 1000 ? "wide" : width >= 700 ? "medium" : "narrow"
    readonly property bool hasRight: cfg.showMedia || cfg.showNetwork || cfg.showReminders || cfg.showNews
    property int tab: 0
    function focusChat() { tab = 0; chat.focusInput() }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: shell.t.background
        border.color: shell.t.border
    }

    // Abas (modo estreito)
    Row {
        id: tabs
        visible: shell.mode === "narrow"
        anchors.top: parent.top; anchors.topMargin: 12; anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        Repeater {
            model: ["Chat", "Painel"]
            delegate: Rectangle {
                required property string modelData
                required property int index
                width: 96; height: 28; radius: 14
                color: shell.tab === index ? shell.t.accentSoft : "transparent"
                border.color: shell.tab === index ? shell.t.accentLine : shell.t.border
                Text { anchors.centerIn: parent; text: modelData; color: shell.tab === index ? shell.t.accent : shell.t.muted; font.pixelSize: 12; font.weight: Font.DemiBold }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: shell.tab = index }
            }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: shell.mode === "narrow" ? 50 : 12

        Flickable {
            id: side
            visible: shell.mode !== "narrow" || shell.tab === 1
            width: shell.mode === "narrow" ? body.width : 284
            height: body.height
            contentHeight: sideColumn.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            B.ScrollBar.vertical: B.ScrollBar { policy: B.ScrollBar.AsNeeded; width: 6 }
            Column {
                id: sideColumn
                width: side.width - (side.contentHeight > side.height ? 8 : 0)
                spacing: shell.t.gap
                ColumnLayout {
                    width: parent.width; spacing: shell.t.gap
                    ClockHeader { t: shell.t; dash: shell.dash; userName: shell.cfg.userName || ""; Layout.leftMargin: 6; Layout.bottomMargin: 4 }
                    WeatherCard { t: shell.t; dash: shell.dash; visible: shell.cfg.showWeather }
                    SystemCard { t: shell.t; dash: shell.dash; visible: shell.cfg.showSystem }
                    ConnectionsCard { t: shell.t; dash: shell.dash; visible: shell.cfg.showConnections }
                }
                Item { id: sideRightHost; width: parent.width; height: childrenRect.height }
            }
        }

        ChatView {
            id: chat
            t: shell.t; client: shell.client
            visible: shell.mode !== "narrow" || shell.tab === 0
            x: shell.mode === "narrow" ? 0 : side.width + shell.t.gap
            width: shell.mode === "narrow" ? body.width
                 : body.width - side.width - shell.t.gap - (right.visible ? right.width + shell.t.gap : 0)
            height: body.height
        }

        Flickable {
            id: right
            visible: shell.mode === "wide" && shell.hasRight
            width: 296; height: body.height
            x: body.width - width
            contentHeight: rightHost.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            B.ScrollBar.vertical: B.ScrollBar { policy: B.ScrollBar.AsNeeded; width: 6 }
            Item { id: rightHost; width: right.width - (right.contentHeight > right.height ? 8 : 0); height: childrenRect.height }
        }
    }

    // Cartões da direita: coluna própria no modo largo, abaixo da lateral nos outros.
    ColumnLayout {
        parent: shell.mode === "wide" ? rightHost : sideRightHost
        width: parent ? parent.width : 0
        spacing: shell.t.gap
        MediaCard { t: shell.t; media: shell.media; visible: shell.cfg.showMedia }
        NetworkCard { t: shell.t; net: shell.net; visible: shell.cfg.showNetwork }
        RemindersCard { t: shell.t; stored: shell.cfg.reminders || "[]"; visible: shell.cfg.showReminders; onSave: json => shell.saveReminders(json) }
        NewsCard { t: shell.t; dash: shell.dash; visible: shell.cfg.showNews }
    }
}
