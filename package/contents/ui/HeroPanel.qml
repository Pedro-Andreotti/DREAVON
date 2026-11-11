import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Topo do widget: logo, horário, clima resumido e um resumo do que importa agora.
// mode: "full" (tudo em linha), "compact" (resumo embaixo), "stacked" (coluna estreita).
Rectangle {
    id: hero
    required property var t
    required property var dash
    required property var client
    required property var media
    required property var net
    property string reminders: "[]"
    property string userName
    property string mode: "full"

    readonly property var w: dash.weatherDetails || ({})
    readonly property var sys: dash.systemDetails || ({})
    readonly property var pending: { try { return JSON.parse(reminders).filter(i => !i.done) } catch (e) { return [] } }

    radius: t.radius + 4
    border.color: t.border
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(hero.t.accent.r, hero.t.accent.g, hero.t.accent.b, 0.18) }
        GradientStop { position: 0.4; color: hero.t.card }
        GradientStop { position: 1; color: hero.t.card }
    }
    implicitHeight: grid.implicitHeight + 28

    function deg(v) { return v > -999 ? v + "°" : "—" }
    function until(reset) {
        const s = reset - Date.now() / 1000
        if (!(reset > 0) || s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
        return h > 0 ? h + "h " + m + "min" : m + "min"
    }
    property real now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: hero.now = Date.now() }

    // Bloco do resumo: ícone, rótulo, valor e detalhe.
    component Tile: Rectangle {
        id: tile
        property string icon
        property url image
        property string label
        property string value
        property string detail
        property color valueColor: hero.t.ink
        property bool clickable: false
        signal activated()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 54
        radius: 11
        color: tileHover.hovered && clickable ? hero.t.cardRaised : Qt.rgba(1, 1, 1, 0.035)
        border.color: hero.t.border
        HoverHandler { id: tileHover; cursorShape: tile.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: tile.clickable; onTapped: tile.activated() }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 9
            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                color: hero.t.accentSoft
                Kirigami.Icon { visible: tile.icon !== ""; anchors.centerIn: parent; source: tile.icon; width: 16; height: 16; isMask: true; color: hero.t.accent }
                Image { visible: tile.image.toString() !== ""; anchors.centerIn: parent; source: tile.image; height: 17; width: 15; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
            }
            ColumnLayout {
                spacing: 0; Layout.fillWidth: true
                Text { text: tile.label; color: hero.t.muted; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.5; font.capitalization: Font.AllUppercase; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: tile.value; color: tile.valueColor; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: text !== ""; text: tile.detail; color: hero.t.faint; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }

    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.margins: 14
        columns: hero.mode === "full" ? 5 : hero.mode === "compact" ? 3 : 1
        columnSpacing: 18; rowSpacing: 12

        // Logo + horário
        ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignTop
            RowLayout {
                spacing: 8
                Image { source: "assets/icon.png"; Layout.preferredWidth: 26; Layout.preferredHeight: 26; sourceSize: Qt.size(64, 64); smooth: true; mipmap: true }
                Image { source: "assets/wordmark.png"; Layout.preferredHeight: 17; Layout.preferredWidth: 17 * 468 / 96; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit }
            }
            RowLayout {
                spacing: 4; Layout.topMargin: 2
                Text { text: (hero.dash.localTime || "--:--").slice(0, 5); color: hero.t.ink; font.pixelSize: 50; font.weight: Font.Light; font.letterSpacing: -2 }
                Text { text: (hero.dash.localTime || "").slice(6, 8); color: hero.t.faint; font.pixelSize: 16; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 10 }
            }
            Text { text: (hero.dash.greeting || "Olá") + (hero.userName ? ", " + hero.userName : ""); color: hero.t.accent; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { text: hero.dash.localDate || ""; color: hero.t.muted; font.pixelSize: 12 }
        }

        Rectangle { visible: hero.mode !== "stacked"; Layout.fillHeight: true; width: 1; color: hero.t.border }

        // Clima resumido
        RowLayout {
            spacing: 10
            Layout.alignment: hero.mode === "stacked" ? Qt.AlignLeft : Qt.AlignVCenter
            Item {
                Layout.preferredWidth: 56; Layout.preferredHeight: 56
                WeatherIcon { anchors.centerIn: parent; scale: 1.3; code: hero.w.code !== undefined ? hero.w.code : (hero.dash.forecast.length ? hero.dash.forecast[0].code : 0); animated: hero.t.animations }
            }
            ColumnLayout {
                spacing: 0
                RowLayout {
                    spacing: 8
                    Text { text: hero.dash.weatherTemperature || "—"; color: hero.t.ink; font.pixelSize: 38; font.weight: Font.Light }
                    Text { text: "↑" + hero.deg(hero.w.high) + "  ↓" + hero.deg(hero.w.low); color: hero.t.muted; font.pixelSize: 12; Layout.alignment: Qt.AlignVCenter }
                }
                RowLayout {
                    spacing: 4
                    Kirigami.Icon { source: "mark-location-symbolic"; implicitWidth: 13; implicitHeight: 13; isMask: true; color: hero.t.accent }
                    Text { text: hero.dash.weatherLocation || "—"; color: hero.t.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "· " + ((hero.dash.weatherSummary || "").split(" · ")[0] || hero.dash.weatherStatus); color: hero.t.muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.maximumWidth: 170 }
                }
            }
        }

        Rectangle { visible: hero.mode === "full"; Layout.fillHeight: true; width: 1; color: hero.t.border }

        // Resumo do que importa agora
        GridLayout {
            Layout.fillWidth: true
            Layout.columnSpan: hero.mode === "compact" ? 3 : 1
            Layout.alignment: Qt.AlignVCenter
            columns: hero.mode === "stacked" ? 2 : 3
            columnSpacing: 8; rowSpacing: 8

            Tile {
                image: "assets/mark.png"
                label: hero.client.providerName
                readonly property real free: hero.client.fiveHourUsed < 0 ? -1 : 100 - hero.client.fiveHourUsed
                value: free < 0 ? (hero.client.modelName || hero.client.status) : Math.round(free) + "% livre (5h)"
                valueColor: free < 0 ? hero.t.ink : hero.t.levelColor(free)
                detail: {
                    hero.now
                    const r = hero.until(hero.client.fiveHourReset)
                    const q = (r ? "renova em " + r : "") + (hero.client.weeklyUsed >= 0 ? (r ? " · " : "") + "semana " + Math.round(100 - hero.client.weeklyUsed) + "%" : "")
                    return q || (hero.client.plan ? hero.client.status + " · " + hero.client.plan : "Clique para alternar IA")
                }
                clickable: !hero.client.busy
                onActivated: hero.client.nextProvider()
            }
            Tile {
                icon: "view-task-symbolic"
                label: "Lembretes"
                value: hero.pending.length === 0 ? "Tudo em dia" : hero.pending.length + (hero.pending.length === 1 ? " pendente" : " pendentes")
                valueColor: hero.pending.length === 0 ? hero.t.good : hero.t.ink
                detail: hero.pending.length ? hero.pending[0].text : "Nada para lembrar"
            }
            Tile {
                icon: hero.dash.batteryPercent >= 0 ? "battery-good-symbolic" : "computer-symbolic"
                label: "Bateria"
                value: hero.dash.batteryPercent >= 0 ? Math.round(hero.dash.batteryPercent) + "%" : "Na tomada"
                valueColor: hero.t.levelColor(hero.dash.batteryPercent)
                detail: [hero.sys.batteryState, hero.sys.batteryTime].filter(Boolean).join(" · ")
            }
            Tile {
                icon: "network-wireless-symbolic"
                label: "Internet"
                value: hero.net.online ? hero.net.latency + " ms" : "Sem conexão"
                valueColor: !hero.net.online ? hero.t.bad : hero.net.latency < 80 ? hero.t.good : hero.net.latency < 200 ? hero.t.warn : hero.t.bad
                detail: [hero.net.connectionName, "↓ " + hero.net.formatRate(hero.net.downloadRate)].filter(Boolean).join(" · ")
            }
            Tile {
                icon: hero.media.playing ? "media-playback-pause" : "media-playback-start-symbolic"
                label: !hero.media.available ? "Música"
                     : hero.media.launching ? "Abrindo " + hero.media.player
                     : !hero.media.live ? "Última · " + hero.media.player
                     : (hero.media.playing ? "Tocando · " : "Pausado · ") + hero.media.player
                value: hero.media.available ? (hero.media.title || "Sem título") : "Nada tocando"
                detail: !hero.media.available ? (hero.media.spotifyInstalled ? "Clique para abrir o Spotify" : "Abra um player")
                      : !hero.media.live ? "Clique para continuar"
                      : (hero.media.artist || (hero.media.playing ? "Clique para pausar" : "Clique para tocar"))
                clickable: hero.media.available || hero.media.spotifyInstalled
                onActivated: hero.media.available ? hero.media.playPause() : hero.media.openSpotify()
            }
            Tile {
                icon: "computer-symbolic"
                label: "Computador"
                value: "CPU " + (hero.dash.cpuUsage >= 0 ? Math.round(hero.dash.cpuUsage) + "%" : "—") + (hero.sys.cpuTemp > 0 ? " · " + Math.round(hero.sys.cpuTemp) + "°C" : "")
                valueColor: hero.t.usageColor(hero.dash.cpuUsage)
                detail: "RAM " + (hero.dash.memoryUsage >= 0 ? Math.round(hero.dash.memoryUsage) + "%" : "—") + (hero.sys.uptime ? " · ligado há " + hero.sys.uptime : "")
            }
        }
    }
}
