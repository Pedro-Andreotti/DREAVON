import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts

// Janela de configurações própria (fora do Plasma), com as páginas Geral, Cartões e Aparência.
// Como no Plasma, cada página expõe cfg_<chave>; ao abrir, os valores vêm de "cfg" (AppSettings) e
// "Aplicar"/"OK" os gravam de volta. Só as chaves de "keys" são copiadas.
Window {
    id: win
    required property var cfg
    // Cofre de credenciais e nome do destino da chave da API (ver CredentialStore).
    property var credentials: null
    property string credentialTarget: ""
    // Sem cofre (outras plataformas): a chave fica em texto puro nas configurações, como antes.
    property var legacyKeyStore: null
    // Atalho global (GlobalHotkey), para a página Geral mostrar a situação e testar combinações.
    property var hotkey: null
    signal applied()
    title: "Configurações"
    width: 720; height: 640
    minimumWidth: 520; minimumHeight: 420
    color: "#14161c"
    flags: Qt.Dialog

    readonly property var keys: [
        "userName", "autoLocation", "cityName", "cityLatitude", "cityLongitude", "defaultProvider", "defaultModel",
        "defaultEffort", "customApiUrl", "customModel", "newsTopic", "calendarUrls", "globalShortcut",
        "showWeather", "showSystem", "showConnections", "showMedia", "showNetwork", "showCalendar", "showReminders", "showNews",
        "accentColor", "backgroundOpacity", "animations"
    ]
    readonly property var pages: [
        {name: "Geral", source: "ConfigGeneral.qml"},
        {name: "Cartões", source: "ConfigCards.qml"},
        {name: "Aparência", source: "ConfigAppearance.qml"}
    ]

    // Tema escuro para os controles desta janela.
    palette {
        window: "#14161c"; windowText: "#e8eaf0"; base: "#1b1d27"; alternateBase: "#232634"
        text: "#e8eaf0"; button: "#232634"; buttonText: "#e8eaf0"; highlight: "#2f8bff"; highlightedText: "#ffffff"
        placeholderText: "#7c8190"; toolTipBase: "#232634"; toolTipText: "#e8eaf0"; mid: "#2c2f3d"; dark: "#0f1014"; light: "#3a3e4f"
    }

    function load(page) {
        if ("hotkey" in page) page.hotkey = hotkey
        for (const key of keys) if (("cfg_" + key) in page) page["cfg_" + key] = cfg[key]
        if ("credentials" in page) {
            page.credentials = credentials; page.credentialTarget = credentialTarget
            page.resetSecrets(); page.refreshKey()
        }
        if (legacyKeyStore && !(credentials && credentials.supported) && ("cfg_customApiKey" in page))
            page.cfg_customApiKey = legacyKeyStore.value("customApiKey", "")
    }
    function apply() {
        for (let i = 0; i < stack.count; ++i) {
            const page = stack.itemAt(i).item
            if (!page) continue
            for (const key of keys) if (("cfg_" + key) in page) cfg[key] = page["cfg_" + key]
            if (legacyKeyStore && !(credentials && credentials.supported) && ("cfg_customApiKey" in page))
                legacyKeyStore.setValue("customApiKey", page.cfg_customApiKey)
        }
        cfg.sync()
        applied()
    }
    onVisibleChanged: if (!visible) for (let i = 0; i < stack.count; ++i) {
        const page = stack.itemAt(i).item
        if (page && ("resetSecrets" in page)) page.resetSecrets()
    }
    function open(index) {
        tabs.currentIndex = index || 0
        for (let i = 0; i < stack.count; ++i) if (stack.itemAt(i).item) load(stack.itemAt(i).item)
        win.show(); win.raise(); win.requestActivate()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        QQC2.TabBar {
            id: tabs
            Layout.fillWidth: true
            Repeater {
                model: win.pages
                QQC2.TabButton { required property var modelData; text: modelData.name }
            }
        }
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex
            Repeater {
                model: win.pages
                Loader {
                    required property var modelData
                    source: modelData.source
                    onLoaded: win.load(item)
                }
            }
        }
        QQC2.DialogButtonBox {
            Layout.fillWidth: true
            QQC2.Button { text: "OK"; QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole }
            QQC2.Button { text: "Aplicar"; QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.ApplyRole }
            QQC2.Button { text: "Cancelar"; QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole }
            onAccepted: { win.apply(); win.close() }
            onRejected: win.close()
            onApplied: win.apply()
        }
    }
}
