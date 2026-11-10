import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B

// Layout principal, com o painel geral (horário, cidade, clima) como base.
//  largo  (≥ 1100): painel geral em cima; embaixo sistema | chat | 2 colunas de cartões
//  médio  (≥ 720):  painel + cartões roláveis à esquerda, chat à direita
//  estreito:        abas Painel / Chat
Item {
    id: shell
    required property var t
    required property var client
    required property var dash
    required property var media
    required property var net
    required property var cfg
    signal saveReminders(string json)

    readonly property string mode: width >= 1100 ? "wide" : width >= 720 ? "medium" : "narrow"
    property int tab: 0   // estreito: 0 = Painel, 1 = Chat
    function focusChat() { if (mode === "narrow") tab = 1; Qt.callLater(() => { if (loader.item && loader.item.chat) loader.item.chat.focusInput() }) }

    Rectangle { anchors.fill: parent; radius: 20; color: shell.t.background; border.color: shell.t.border }

    Row {
        visible: shell.mode === "narrow"
        anchors.top: parent.top; anchors.topMargin: 12; anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4; z: 2
        Repeater {
            model: ["Painel", "Chat"]
            delegate: Rectangle {
                required property string modelData
                required property int index
                width: 104; height: 28; radius: 14
                color: shell.tab === index ? shell.t.accentSoft : "transparent"
                border.color: shell.tab === index ? shell.t.accentLine : shell.t.border
                Text { anchors.centerIn: parent; text: modelData; color: shell.tab === index ? shell.t.accent : shell.t.muted; font.pixelSize: 12; font.weight: Font.DemiBold }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: shell.tab = index }
            }
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: shell.mode === "narrow" ? 50 : 12
        sourceComponent: shell.mode === "wide" ? wideLayout : shell.mode === "medium" ? mediumLayout : narrowLayout
    }

    // Cartões reutilizados nos layouts empilhados (médio e estreito).
    component CardStack: ColumnLayout {
        spacing: shell.t.gap
        SystemCard { t: shell.t; dash: shell.dash; visible: shell.cfg.showSystem }
        ConnectionsCard { t: shell.t; dash: shell.dash; visible: shell.cfg.showConnections }
        MediaCard { t: shell.t; media: shell.media; visible: shell.cfg.showMedia }
        NetworkCard { t: shell.t; net: shell.net; visible: shell.cfg.showNetwork }
        CalendarCard { t: shell.t; visible: shell.cfg.showCalendar !== false }
        RemindersCard { t: shell.t; stored: shell.cfg.reminders || "[]"; visible: shell.cfg.showReminders; onSave: json => shell.saveReminders(json) }
        NewsCard { t: shell.t; dash: shell.dash; visible: shell.cfg.showNews; listHeight: 300 }
        WeatherFooter { t: shell.t; dash: shell.dash; compact: true; Layout.fillWidth: true }
    }

    component Scroller: Flickable {
        clip: true; boundsBehavior: Flickable.StopAtBounds
        B.ScrollBar.vertical: B.ScrollBar { policy: B.ScrollBar.AsNeeded; width: 6 }
    }

    Component {
        id: wideLayout
        Item {
            property alias chat: chatView
            HeroPanel {
                id: hero
                width: parent.width
                t: shell.t; dash: shell.dash; client: shell.client; media: shell.media; net: shell.net; reminders: shell.cfg.reminders || "[]"; userName: shell.cfg.userName || ""; mode: "full"
            }
            WeatherFooter {
                id: footer
                t: shell.t; dash: shell.dash
                width: parent.width
                y: parent.height - height
            }
            Item {
                id: lower
                y: hero.height + shell.t.gap
                width: parent.width; height: footer.y - shell.t.gap - y
                readonly property bool hasLeft: shell.cfg.showSystem || shell.cfg.showConnections || shell.cfg.showNetwork
                readonly property int leftWidth: hasLeft ? 286 : 0
                readonly property int chatWidth: Math.round(Math.max(340, Math.min(440, width * 0.32)))

                // Rola só se o conteúdo não couber; se couber, o último cartão estica até o fim.
                Scroller {
                    id: leftScroll
                    visible: lower.hasLeft
                    width: lower.leftWidth; height: lower.height
                    contentHeight: Math.max(height, leftColumn.implicitHeight)
                ColumnLayout {
                    id: leftColumn
                    width: leftScroll.width - (leftColumn.implicitHeight > leftScroll.height ? 8 : 0)
                    height: leftScroll.contentHeight
                    spacing: shell.t.gap
                    SystemCard { id: system; t: shell.t; dash: shell.dash; visible: shell.cfg.showSystem; Layout.fillHeight: !devices.visible && !network.visible }
                    ConnectionsCard { id: devices; t: shell.t; dash: shell.dash; visible: shell.cfg.showConnections; Layout.fillHeight: !network.visible }
                    NetworkCard { id: network; t: shell.t; net: shell.net; visible: shell.cfg.showNetwork; Layout.fillHeight: true; Layout.minimumHeight: implicitHeight }
                }
                }

                ChatView {
                    id: chatView
                    t: shell.t; client: shell.client
                    x: lower.hasLeft ? lower.leftWidth + shell.t.gap : 0
                    width: lower.chatWidth; height: lower.height
                }

                // Duas colunas; o último cartão de cada uma ocupa o espaço que sobra.
                RowLayout {
                    x: chatView.x + chatView.width + shell.t.gap
                    width: lower.width - x; height: lower.height
                    spacing: shell.t.gap
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                        spacing: shell.t.gap
                        visible: music.visible || calendar.visible
                        MediaCard { id: music; t: shell.t; media: shell.media; visible: shell.cfg.showMedia; Layout.fillHeight: !calendar.visible }
                        CalendarCard { id: calendar; t: shell.t; visible: shell.cfg.showCalendar !== false; Layout.fillHeight: true }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                        spacing: shell.t.gap
                        visible: reminders.visible || news.visible
                        RemindersCard { id: reminders; t: shell.t; stored: shell.cfg.reminders || "[]"; visible: shell.cfg.showReminders; onSave: json => shell.saveReminders(json); Layout.fillHeight: !news.visible }
                        NewsCard { id: news; t: shell.t; dash: shell.dash; visible: shell.cfg.showNews; Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    Component {
        id: mediumLayout
        Item {
            property alias chat: chatView
            readonly property int chatWidth: Math.round(Math.max(330, Math.min(400, width * 0.42)))
            Scroller {
                id: scroller
                width: parent.width - chatWidth - shell.t.gap; height: parent.height
                contentHeight: column.implicitHeight
                ColumnLayout {
                    id: column
                    width: scroller.width - (scroller.contentHeight > scroller.height ? 8 : 0)
                    spacing: shell.t.gap
                    HeroPanel { t: shell.t; dash: shell.dash; client: shell.client; media: shell.media; net: shell.net; reminders: shell.cfg.reminders || "[]"; userName: shell.cfg.userName || ""; mode: "compact"; Layout.fillWidth: true }
                    CardStack { Layout.fillWidth: true }
                }
            }
            ChatView {
                id: chatView
                t: shell.t; client: shell.client
                x: parent.width - width; width: parent.chatWidth; height: parent.height
            }
        }
    }

    Component {
        id: narrowLayout
        Item {
            property alias chat: chatView
            Scroller {
                id: scroller
                anchors.fill: parent
                visible: shell.tab === 0
                contentHeight: column.implicitHeight
                ColumnLayout {
                    id: column
                    width: scroller.width - (scroller.contentHeight > scroller.height ? 8 : 0)
                    spacing: shell.t.gap
                    HeroPanel { t: shell.t; dash: shell.dash; client: shell.client; media: shell.media; net: shell.net; reminders: shell.cfg.reminders || "[]"; userName: shell.cfg.userName || ""; mode: "stacked"; Layout.fillWidth: true }
                    CardStack { Layout.fillWidth: true }
                }
            }
            ChatView { id: chatView; anchors.fill: parent; visible: shell.tab === 1; t: shell.t; client: shell.client }
        }
    }
}
