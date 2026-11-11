import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "bridge" as Backend

// Janela principal do DREAVON, fora do Plasma: sem moldura do sistema, fundo escuro com
// cantos arredondados, arrastável pela barra de título e redimensionável pelas bordas.
Window {
    id: root
    title: "Plasdria"
    width: 1280; height: 800
    minimumWidth: 340; minimumHeight: 480
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    AppSettings { id: settings }
    readonly property var cfg: settings
    property bool layoutEditing: false

    // Traz a janela para a frente e põe o foco no chat.
    function showPanel() {
        if (root.visibility === Window.Minimized || !root.visible) root.showNormal()
        root.raise(); root.requestActivate()
        shell.focusChat()
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
        customApiKey: ""  // TODO(etapa 7): ler do cofre de credenciais
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
        let changed = false
        for (const item of list) {
            if (item.done || !(item.due > 0) || item.notified || item.due > now) continue
            item.notified = true; changed = true
            // Lembretes muito antigos (aplicativo estava fechado) são só marcados, sem barulho.
            if (now - item.due < 6 * 3600 * 1000) dashBackend.notify("Lembrete", item.text)
        }
        if (changed) cfg.reminders = JSON.stringify(list)
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
            Text {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: root.title
                color: themeBackend.muted
                font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.2
            }
            Row {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 4
                IconButton { t: themeBackend; icon: "go-down"; tip: "Minimizar"; size: 24; onClicked: root.showMinimized() }
                IconButton { t: themeBackend; icon: "window-close"; tip: "Fechar"; size: 24; onClicked: root.close() }
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

    Component.onCompleted: shell.focusChat()
}
