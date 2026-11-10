import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Card {
    id: card
    required property var media
    title: media.available ? "Tocando · " + media.player : "Música"
    icon: "media-playback-start-symbolic"
    function clock(seconds) {
        if (!(seconds > 0)) return "0:00"
        const s = Math.floor(seconds), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0")
    }

    Text {
        visible: !card.media.available
        text: "Nada tocando. Abra o Spotify, um vídeo ou qualquer player."
        color: card.t.faint; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
    }
    RowLayout {
        visible: card.media.available
        spacing: 12; Layout.fillWidth: true
        Rectangle {
            Layout.preferredWidth: 64; Layout.preferredHeight: 64
            radius: 10; color: card.t.cardRaised; clip: true
            Image {
                id: art
                anchors.fill: parent; anchors.margins: 0
                source: card.media.artUrl; fillMode: Image.PreserveAspectCrop
                asynchronous: true; sourceSize: Qt.size(128, 128)
                visible: status === Image.Ready
            }
            Kirigami.Icon { anchors.centerIn: parent; visible: !art.visible; source: "media-album-cover"; width: 28; height: 28; isMask: true; color: card.t.faint }
            TapHandler { onTapped: card.media.raise() }
        }
        ColumnLayout {
            spacing: 1; Layout.fillWidth: true
            Text { text: card.media.title || "Sem título"; color: card.t.ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 2; wrapMode: Text.Wrap }
            Text { text: card.media.artist || card.media.album || ""; visible: text !== ""; color: card.t.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
    ColumnLayout {
        visible: card.media.available && card.media.length > 0
        spacing: 2; Layout.fillWidth: true
        Item {
            Layout.fillWidth: true; height: 12
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: seekHover.hovered ? 6 : 4; radius: 3; color: card.t.border
                Behavior on height { NumberAnimation { duration: 120 } }
                Rectangle { width: parent.width * Math.min(1, card.media.position / Math.max(1, card.media.length)); height: parent.height; radius: 3; color: card.t.accent }
            }
            HoverHandler { id: seekHover; cursorShape: card.media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: card.media.canSeek; onTapped: point => card.media.seek(card.media.length * point.position.x / parent.width) }
        }
        RowLayout {
            Text { text: card.clock(card.media.position); color: card.t.faint; font.pixelSize: 10 }
            Item { Layout.fillWidth: true }
            Text { text: card.clock(card.media.length); color: card.t.faint; font.pixelSize: 10 }
        }
    }
    RowLayout {
        visible: card.media.available
        Layout.alignment: Qt.AlignHCenter; spacing: 10
        IconButton { t: card.t; icon: "media-skip-backward"; tip: "Anterior"; enabled: card.media.canGoPrevious; onClicked: card.media.previous() }
        IconButton { t: card.t; icon: card.media.playing ? "media-playback-pause" : "media-playback-start"; tip: card.media.playing ? "Pausar" : "Tocar"; primary: true; size: 34; onClicked: card.media.playPause() }
        IconButton { t: card.t; icon: "media-skip-forward"; tip: "Próxima"; enabled: card.media.canGoNext; onClicked: card.media.next() }
    }
}
