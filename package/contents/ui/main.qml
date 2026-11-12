import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as B
import QtCore
import Qt.labs.platform as Platform
import "bridge" as Backend

// Janela principal do DREAVON, fora do Plasma: sem moldura do sistema, fundo escuro com
// cantos arredondados, arrastável pela barra de título e redimensionável pelas bordas.
Window {
    id: root
    title: "DREAVON"
    width: 1280; height: 800
    minimumWidth: 340; minimumHeight: 480
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    AppSettings { id: settings }
    readonly property var cfg: settings

    // Chave da API compatível: no Windows fica no Gerenciador de Credenciais e o ClaudeClient a lê
    // de lá só na hora da requisição. Em outras plataformas segue em texto puro nas configurações.
    Backend.CredentialStore { id: credentialStore }
    Settings { id: legacyKeySettings; location: settings.location }   // sem propriedades: só value/setValue
    property string legacyApiKey: ""
    function reloadLegacyKey() { if (!credentialStore.supported) legacyApiKey = String(legacyKeySettings.value("customApiKey", "")) }
    Connections {
        target: credentialStore
        function onChanged() { if (claudeBackend.provider === "custom" && !claudeBackend.busy) claudeBackend.reconnect() }
    }
    property bool layoutEditing: false

    // Traz a janela para a frente e põe o foco no chat.
    function showPanel() {
        if (root.visibility === Window.Minimized || !root.visible) root.showNormal()
        root.raise(); root.requestActivate()
        shell.focusChat()
    }
    function togglePanel() {
        if (root.visible && root.visibility !== Window.Minimized && root.active) root.hide()
        else root.showPanel()
    }
    // Fechar a janela só a esconde: o DREAVON continua na bandeja (sai pelo menu "Sair").
    onClosing: close => { close.accepted = false; root.hide() }

    // As quatro ações do antigo menu do plasmoide (bandeja e clique direito na barra de título).
    readonly property var panelActions: [
        {text: "Nova conversa", run: () => { claudeBackend.newChat(); root.showPanel() }},
        {text: "Alternar IA (" + claudeBackend.providerName + ")", run: () => { claudeBackend.nextProvider(); root.showPanel() }},
        {text: root.layoutEditing ? "Concluir a edição do layout" : "Editar layout", run: () => { root.layoutEditing = !root.layoutEditing; root.showPanel() }},
        {text: "Reconectar ao " + claudeBackend.providerName, run: () => claudeBackend.reconnect()}
    ]

    SettingsWindow {
        id: settingsWindow
        cfg: settings
        credentials: credentialStore
        credentialTarget: settings.customApiKeyTarget
        legacyKeyStore: legacyKeySettings
        hotkey: globalHotkey
        onApplied: root.reloadLegacyKey()
    }

    Platform.SystemTrayIcon {
        id: tray
        visible: true
        icon.source: Qt.resolvedUrl("assets/dreavon.ico")
        tooltip: {
            const used = claudeBackend.fiveHourUsed
            return root.title + "\n" + claudeBackend.providerName + " · " + claudeBackend.status
                + (used >= 0 ? " · " + Math.round(100 - used) + "% da cota de 5h livre" : "")
        }
        onActivated: reason => { if (reason === Platform.SystemTrayIcon.Trigger) root.togglePanel() }
        // Clique na notificação (toast) de um lembrete: mostra o painel.
        onMessageClicked: root.showPanel()
        menu: Platform.Menu {
            Platform.MenuItem {
                text: root.visible ? "Ocultar" : "Mostrar"
                onTriggered: root.visible ? root.hide() : root.showPanel()
            }
            Platform.MenuSeparator {}
            Platform.MenuItem { text: root.panelActions[0].text; onTriggered: root.panelActions[0].run() }
            Platform.MenuItem { text: root.panelActions[1].text; onTriggered: root.panelActions[1].run() }
            Platform.MenuItem { text: root.panelActions[2].text; onTriggered: root.panelActions[2].run() }
            Platform.MenuItem { text: root.panelActions[3].text; onTriggered: root.panelActions[3].run() }
            Platform.MenuSeparator {}
            Platform.MenuItem { text: "Configurações…"; onTriggered: settingsWindow.open(0) }
            Platform.MenuItem { text: "Sair"; onTriggered: Qt.quit() }
        }
    }

    Theme {
        id: themeBackend
        accent: root.cfg.accentColor || "#2f8bff"
        backgroundOpacity: (root.cfg.backgroundOpacity || 94) / 100
        animations: root.cfg.animations
    }

    Backend.ClaudeClient {
        id: claudeBackend
        property bool defaultsApplied: false
        customApiUrl: root.cfg.customApiUrl || "https://api.openai.com/v1"
        customApiKey: credentialStore.supported ? "" : root.legacyApiKey
        customApiKeyTarget: credentialStore.supported ? root.cfg.customApiKeyTarget : ""
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

    // Atalho global (Windows): mesmo efeito do clique no ícone da bandeja. Nas outras plataformas,
    // GlobalHotkey não faz nada (supported = false).
    Backend.GlobalHotkey {
        id: globalHotkey
        sequence: root.cfg.globalShortcut || ""
        onActivated: root.togglePanel()
    }

    // Windows: a notificação sai pelo ícone da bandeja (o Windows 10/11 a mostra como toast).
    Connections {
        target: dashBackend
        function onNotificationRequested(title, body) { tray.showMessage(title, body, Platform.SystemTrayIcon.Information, 15000) }
    }

    // Alarmes dos lembretes: avisa uma vez quando chega a hora (mesmo com a janela oculta).
    Timer {
        interval: 15000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.checkReminders()
    }
    function checkReminders() {
        let list
        try { list = JSON.parse(cfg.reminders || "[]") } catch (e) { return }
        if (!Array.isArray(list)) return
        const now = Date.now()
        const windows = Qt.platform.os === "windows"
        const fired = []
        let changed = false
        for (const item of list) {
            if (item.done || !(item.due > 0) || item.notified || item.due > now) continue
            item.notified = true; changed = true
            // Lembretes muito antigos (aplicativo estava fechado) são só marcados, sem barulho.
            if (now - item.due >= 6 * 3600 * 1000) continue
            if (!windows) { dashBackend.notify("Lembrete", item.text); continue }
            // Windows: marca no cartão que o alarme tocou (não se perde com o Não Perturbe ligado).
            item.alarmAt = now
            fired.push(item)
        }
        if (fired.length) root.announceReminders(fired, now)
        if (changed) cfg.reminders = JSON.stringify(list)
    }
    // Uma notificação só por verificação: vários alarmes juntos (ou atrasados, depois de o PC voltar da
    // suspensão) viram um aviso agrupado, com até 3 textos.
    function announceReminders(fired, now) {
        const late = fired.filter(i => now - i.due > 2 * 60 * 1000).length
        if (fired.length === 1) {
            dashBackend.notify(late ? "Lembrete atrasado" : "Lembrete", fired[0].text)
            return
        }
        const title = fired.length + (late === fired.length ? " lembretes atrasados" : " lembretes")
        const lines = fired.slice(0, 3).map(i => "• " + i.text)
        if (fired.length > 3) lines.push("…e mais " + (fired.length - 3))
        dashBackend.notify(title, lines.join("\n"))
    }

    IcsFeed { id: calendarFeed; urls: root.cfg.calendarUrls || "" }

    Backend.MediaClient { id: mediaBackend }
    Backend.NetworkClient { id: netBackend }

    // Fundo arredondado (com a opacidade das configurações).
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.visibility === Window.Maximized ? 0 : themeBackend.radius
        color: themeBackend.background
        border.color: themeBackend.border
        border.width: 1

        // Barra de título: arrasta a janela; duplo clique maximiza/restaura.
        Item {
            id: titleBar
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 34
            DragHandler {
                target: null
                onActiveChanged: if (active) root.startSystemMove()
            }
            TapHandler {
                onDoubleTapped: root.visibility === Window.Maximized ? root.showNormal() : root.showMaximized()
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: windowMenu.popup()
            }
            B.Menu {
                id: windowMenu
                Repeater {
                    model: root.panelActions
                    B.MenuItem { required property var modelData; text: modelData.text; onTriggered: modelData.run() }
                }
                B.MenuSeparator {}
                B.MenuItem { text: "Configurações…"; onTriggered: settingsWindow.open(0) }
            }
            Text {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: root.title
                color: themeBackend.muted
                font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.2
            }
            Row {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 4
                IconButton { t: themeBackend; icon: "configure"; tip: "Configurações"; size: 24; onClicked: settingsWindow.open(0) }
                IconButton { t: themeBackend; icon: "go-down"; tip: "Minimizar"; size: 24; onClicked: root.showMinimized() }
                IconButton { t: themeBackend; icon: "window-close"; tip: "Fechar (continua na bandeja)"; size: 24; onClicked: root.close() }
            }
        }

        Shell {
            id: shell
            anchors { left: parent.left; right: parent.right; top: titleBar.bottom; bottom: parent.bottom; margins: 10; topMargin: 0 }
            t: themeBackend; client: claudeBackend; dash: dashBackend; media: mediaBackend; net: netBackend; cfg: root.cfg
            editing: root.layoutEditing
            events: calendarFeed.events; feedConfigured: calendarFeed.configured; feedStatus: calendarFeed.status
            onEditRequested: on => root.layoutEditing = on
            onSaveReminders: json => root.cfg.reminders = json
            onSaveLayout: json => root.cfg.layout = json
        }
    }

    // Bordas para redimensionar (a janela não tem moldura do sistema).
    component ResizeEdge: MouseArea {
        required property int edges
        hoverEnabled: true
        enabled: root.visibility !== Window.Maximized
        cursorShape: edges === (Qt.LeftEdge | Qt.TopEdge) || edges === (Qt.RightEdge | Qt.BottomEdge) ? Qt.SizeFDiagCursor
                   : edges === (Qt.RightEdge | Qt.TopEdge) || edges === (Qt.LeftEdge | Qt.BottomEdge) ? Qt.SizeBDiagCursor
                   : (edges & (Qt.LeftEdge | Qt.RightEdge)) ? Qt.SizeHorCursor : Qt.SizeVerCursor
        onPressed: root.startSystemResize(edges)
    }
    readonly property int grip: 6
    ResizeEdge { edges: Qt.LeftEdge; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: root.grip; bottomMargin: root.grip } width: root.grip }
    ResizeEdge { edges: Qt.RightEdge; anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: root.grip; bottomMargin: root.grip } width: root.grip }
    ResizeEdge { edges: Qt.TopEdge; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: root.grip; rightMargin: root.grip } height: root.grip }
    ResizeEdge { edges: Qt.BottomEdge; anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: root.grip; rightMargin: root.grip } height: root.grip }
    ResizeEdge { edges: Qt.LeftEdge | Qt.TopEdge; anchors { left: parent.left; top: parent.top } width: root.grip; height: root.grip }
    ResizeEdge { edges: Qt.RightEdge | Qt.TopEdge; anchors { right: parent.right; top: parent.top } width: root.grip; height: root.grip }
    ResizeEdge { edges: Qt.LeftEdge | Qt.BottomEdge; anchors { left: parent.left; bottom: parent.bottom } width: root.grip; height: root.grip }
    ResizeEdge { edges: Qt.RightEdge | Qt.BottomEdge; anchors { right: parent.right; bottom: parent.bottom } width: root.grip; height: root.grip }

    Component.onCompleted: {
        // Migração: uma chave antiga em texto puro nas configurações vai para o cofre e sai do arquivo.
        if (credentialStore.supported) credentialStore.migrateFromSettings(settings.location, "customApiKey", settings.customApiKeyTarget)
        else reloadLegacyKey()
        shell.focusChat()
    }
}
