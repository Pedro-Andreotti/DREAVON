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
    property bool layoutEditing: false

    toolTipMainText: "Plasdria"
    toolTipSubText: {
        const used = claudeBackend.fiveHourUsed
        return claudeBackend.providerName + " · " + claudeBackend.status + (used >= 0 ? " · " + Math.round(100 - used) + "% da cota de 5h livre" : "")
    }

    Theme {
        id: themeBackend
        accent: root.cfg.accentColor || "#3daee9"
        backgroundOpacity: (root.cfg.backgroundOpacity || 94) / 100
        animations: root.cfg.animations
    }

    Backend.ClaudeClient {
        id: claudeBackend
        property bool defaultsApplied: false
        customApiUrl: root.cfg.customApiUrl || "https://api.openai.com/v1"
        customApiKey: root.cfg.customApiKey || ""
        customModel: root.cfg.customModel || ""
        Component.onCompleted: {
            if (!hasSavedProvider && root.cfg.defaultProvider) provider = root.cfg.defaultProvider
            start()
        }
        onChanged: {
            // Modelo e esforço das configurações valem ao iniciar; trocas no chat valem até reiniciar.
            if (defaultsApplied || !ready) return
            defaultsApplied = true
            root.applyModelDefaults()
        }
    }
    function applyModelDefaults() {
        if (claudeBackend.models.some(m => m.id === cfg.defaultModel)) claudeBackend.model = cfg.defaultModel
        if (claudeBackend.efforts.indexOf(cfg.defaultEffort) >= 0) claudeBackend.effort = cfg.defaultEffort
    }

    Backend.DashboardClient {
        id: dashBackend
        Component.onCompleted: { root.applyLocation(); setNewsTopic(root.cfg.newsTopic || ""); start() }
    }
    function applyLocation() {
        if (cfg.autoLocation) dashBackend.setLocation("", 0, 0)
        else dashBackend.setLocation(cfg.cityName, cfg.cityLatitude, cfg.cityLongitude)
    }
    readonly property string locationKey: [cfg.autoLocation, cfg.cityName, cfg.cityLatitude, cfg.cityLongitude].join("|")
    onLocationKeyChanged: applyLocation()
    readonly property string newsTopic: cfg.newsTopic || ""
    onNewsTopicChanged: dashBackend.setNewsTopic(newsTopic)
    readonly property string defaultProviderCfg: cfg.defaultProvider || "antigravity"
    onDefaultProviderCfgChanged: if (!claudeBackend.busy) claudeBackend.provider = defaultProviderCfg
    readonly property string modelKey: cfg.defaultModel + "|" + cfg.defaultEffort
    onModelKeyChanged: if (claudeBackend.ready && !claudeBackend.busy) applyModelDefaults()

    // Alarmes dos lembretes: avisa uma vez quando chega a hora (mesmo com o painel fechado).
    Timer {
        interval: 15000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.checkReminders()
    }
    function checkReminders() {
        let list
        try { list = JSON.parse(cfg.reminders || "[]") } catch (e) { return }
        if (!Array.isArray(list)) return
        const now = Date.now()
        let changed = false
        for (const item of list) {
            if (item.done || !(item.due > 0) || item.notified || item.due > now) continue
            item.notified = true; changed = true
            // Lembretes muito antigos (widget estava fechado) são só marcados, sem barulho.
            if (now - item.due < 6 * 3600 * 1000) dashBackend.notify("Lembrete", item.text)
        }
        if (changed) cfg.reminders = JSON.stringify(list)
    }

    IcsFeed { id: calendarFeed; urls: root.cfg.calendarUrls || "" }

    Backend.MediaClient { id: mediaBackend }
    Backend.NetworkClient { id: netBackend }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Nova conversa"
            icon.name: "list-add"
            onTriggered: { claudeBackend.newChat(); root.expanded = true }
        },
        PlasmaCore.Action {
            text: "Alternar IA (" + claudeBackend.providerName + ")"
            icon.name: "Synchronize"
            onTriggered: { claudeBackend.nextProvider(); root.expanded = true }
        },
        PlasmaCore.Action {
            text: root.layoutEditing ? "Concluir a edição do layout" : "Editar layout"
            icon.name: "document-edit"
            onTriggered: { root.layoutEditing = !root.layoutEditing; root.expanded = true }
        },
        PlasmaCore.Action {
            text: "Reconectar ao " + claudeBackend.providerName
            icon.name: "view-refresh"
            onTriggered: claudeBackend.reconnect()
        }
    ]

    fullRepresentation: Shell {
        id: shell
        t: themeBackend; client: claudeBackend; dash: dashBackend; media: mediaBackend; net: netBackend; cfg: root.cfg
        editing: root.layoutEditing
        events: calendarFeed.events; feedConfigured: calendarFeed.configured; feedStatus: calendarFeed.status
        onEditRequested: on => root.layoutEditing = on
        onSaveReminders: json => root.cfg.reminders = json
        onSaveLayout: json => root.cfg.layout = json
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
        t: themeBackend; client: claudeBackend
        onClicked: root.expanded = !root.expanded
    }
}
