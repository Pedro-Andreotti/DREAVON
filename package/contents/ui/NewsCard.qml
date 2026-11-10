import QtQuick
import QtQuick.Layouts

// Manchetes em rotação, uma por vez; pausa com o mouse em cima.
Card {
    id: card
    required property var dash
    title: "Notícias"
    icon: "news-subscribe-symbolic"
    property int index: 0
    readonly property var item: dash.news.length ? dash.news[index % dash.news.length] : null
    function step(delta) { if (dash.news.length) { fade.restart(); index = (index + delta + dash.news.length) % dash.news.length } }
    function cleanTitle(item) {
        if (!item) return ""
        const source = item.source || ""
        const title = item.title || ""
        return source && title.endsWith(" - " + source) ? title.slice(0, -(source.length + 3)) : title
    }
    Connections { target: card.dash; function onNewsChanged() { card.index = 0 } }
    Timer { interval: 30000; repeat: true; running: !newsHover.hovered && card.dash.news.length > 1; onTriggered: card.step(1) }

    actions: [
        IconButton { t: card.t; icon: "go-previous"; size: 22; tip: "Anterior"; onClicked: card.step(-1) },
        IconButton { t: card.t; icon: "go-next"; size: 22; tip: "Próxima"; onClicked: card.step(1) },
        IconButton { t: card.t; icon: "view-refresh"; size: 22; tip: "Atualizar"; onClicked: card.dash.refresh() }
    ]
    Item {
        Layout.fillWidth: true
        implicitHeight: headline.implicitHeight + source.implicitHeight + 6
        HoverHandler { id: newsHover; cursorShape: card.item && card.item.link ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (card.item && card.item.link) Qt.openUrlExternally(card.item.link) }
        NumberAnimation { id: fade; target: headline; property: "opacity"; from: 0; to: 1; duration: card.t.animations ? 350 : 0 }
        Text {
            id: headline; width: parent.width
            text: card.item ? card.cleanTitle(card.item) : card.dash.newsStatus
            color: newsHover.hovered ? card.t.accent : card.t.ink; font.pixelSize: 13; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        Text {
            id: source; anchors.top: headline.bottom; anchors.topMargin: 6
            text: card.item ? (card.item.source || "Google News") + " · " + ((card.index % Math.max(1, card.dash.news.length)) + 1) + "/" + card.dash.news.length : ""
            color: card.t.faint; font.pixelSize: 10
        }
    }
}
