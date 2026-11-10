import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "bridge" as Backend

PlasmoidItem {
    id: root
    readonly property var cfg: Plasmoid.configuration
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation
    switchWidth: 340; switchHeight: 420

    toolTipMainText: "Plasdria"
    toolTipSubText: {
        const used = client.fiveHourUsed
        return "Claude · " + client.status + (used >= 0 ? " · " + Math.round(100 - used) + "% da cota de 5h livre" : "")
    }

    Theme {
        id: theme
        accent: root.cfg.accentColor || "#3daee9"
        backgroundOpacity: (root.cfg.backgroundOpacity || 94) / 100
        animations: root.cfg.animations
    }

    Backend.ClaudeClient {
        id: client
        property bool defaultsApplied: false
        Component.onCompleted: start()
        onChanged: {
            // Modelo e esforço das configurações valem ao iniciar; trocas no chat valem até reiniciar.
            if (defaultsApplied || !ready) return
            defaultsApplied = true
            root.applyModelDefaults()
        }
    }
    function applyModelDefaults() {
        if (client.models.some(m => m.id === cfg.defaultModel)) client.model = cfg.defaultModel
        if (client.efforts.indexOf(cfg.defaultEffort) >= 0) client.effort = cfg.defaultEffort
    }

    Backend.DashboardClient {
        id: dash
        Component.onCompleted: { root.applyLocation(); setNewsTopic(root.cfg.newsTopic || ""); start() }
    }
    function applyLocation() {
        if (cfg.autoLocation) dash.setLocation("", 0, 0)
        else dash.setLocation(cfg.cityName, cfg.cityLatitude, cfg.cityLongitude)
    }
    readonly property string locationKey: [cfg.autoLocation, cfg.cityName, cfg.cityLatitude, cfg.cityLongitude].join("|")
    onLocationKeyChanged: applyLocation()
    readonly property string newsTopic: cfg.newsTopic || ""
    onNewsTopicChanged: dash.setNewsTopic(newsTopic)
    readonly property string modelKey: cfg.defaultModel + "|" + cfg.defaultEffort
    onModelKeyChanged: if (client.ready && !client.busy) applyModelDefaults()

    Backend.MediaClient { id: media }
    Backend.NetworkClient { id: net }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Nova conversa"
            icon.name: "list-add"
            onTriggered: { client.newChat(); root.expanded = true }
        },
        PlasmaCore.Action {
            text: "Reconectar ao Claude"
            icon.name: "view-refresh"
            onTriggered: client.reconnect()
        }
    ]

    fullRepresentation: Shell {
        id: shell
        t: theme; client: client; dash: dash; media: media; net: net; cfg: root.cfg
        onSaveReminders: json => root.cfg.reminders = json
        Layout.minimumWidth: 340
        Layout.minimumHeight: 480
        Layout.preferredWidth: 1280
        Layout.preferredHeight: 800
        Connections {
            target: root
            function onExpandedChanged() { if (root.expanded) shell.focusChat() }
        }
    }

    compactRepresentation: CompactIcon {
        t: theme; client: client
        onClicked: root.expanded = !root.expanded
    }
}
