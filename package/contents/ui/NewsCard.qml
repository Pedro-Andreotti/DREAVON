import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B

// Lista de manchetes com fonte e horário; clique abre a notícia.
Card {
    id: card
    required property var dash
    property int listHeight: 0   // 0 = ocupa a altura do cartão
    title: "Notícias"
    stretch: listHeight === 0
    icon: "news-subscribe-symbolic"
    function cleanTitle(item) {
        const source = item.source || "", title = item.title || ""
        return source && title.endsWith(" - " + source) ? title.slice(0, -(source.length + 3)) : title
    }
    function ago(pubDate) {
        const d = new Date(pubDate); if (isNaN(d.getTime())) return ""
        const m = Math.max(0, Math.round((Date.now() - d.getTime()) / 60000))
        return m < 60 ? "há " + m + " min" : m < 1440 ? "há " + Math.round(m / 60) + " h" : "há " + Math.round(m / 1440) + " d"
    }
    actions: [ IconButton { t: card.t; icon: "view-refresh"; size: 22; tip: "Atualizar"; onClicked: card.dash.refresh() } ]

    Text { visible: card.dash.news.length === 0; text: card.dash.newsStatus; color: card.t.faint; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
    ListView {
        id: list
        visible: card.dash.news.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: card.listHeight === 0
        Layout.preferredHeight: card.listHeight > 0 ? card.listHeight : 60
        clip: true; spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: card.dash.news
        B.ScrollBar.vertical: B.ScrollBar { policy: B.ScrollBar.AsNeeded; width: 5 }
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: list.width - 6
            height: col.implicitHeight + 12; radius: 8
            color: hover.hovered ? card.t.cardRaised : "transparent"
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (modelData.link) Qt.openUrlExternally(modelData.link) }
            ColumnLayout {
                id: col
                x: 6; y: 6; width: parent.width - 12; spacing: 2
                Text {
                    text: card.cleanTitle(modelData); textFormat: Text.PlainText
                    color: hover.hovered ? card.t.accent : card.t.ink; font.pixelSize: 12
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text { text: [modelData.source || "Google News", card.ago(modelData.pubDate)].filter(Boolean).join(" · "); color: card.t.faint; font.pixelSize: 10 }
            }
        }
    }
}
