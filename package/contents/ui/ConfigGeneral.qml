import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
    id: page
    property alias cfg_userName: userName.text
    property alias cfg_autoLocation: autoLocation.checked
    property string cfg_cityName
    property real cfg_cityLatitude
    property real cfg_cityLongitude
    property string cfg_defaultProvider
    property string cfg_defaultModel
    property string cfg_defaultEffort
    property alias cfg_customApiUrl: customApiUrl.text
    property alias cfg_customApiKey: customApiKey.text
    property alias cfg_customModel: customModel.text
    property string cfg_newsTopic
    property alias cfg_calendarUrls: calendarUrls.text
    property string cfg_globalShortcut

    // Atalho global (GlobalHotkey), definido pela SettingsWindow ao carregar a página. Só no Windows.
    property var hotkey: null
    readonly property bool hotkeySupported: !!hotkey && hotkey.supported
    readonly property string defaultShortcut: "Ctrl+Shift+Alt+D"
    property string capturing: ""   // modificadores já pressionados durante a captura
    // Situação do atalho escolhido: o registrado (aceito ou recusado) ou o teste de um novo.
    readonly property string shortcutMessage: {
        if (!hotkeySupported) return ""
        if (!cfg_globalShortcut) return "Sem atalho global."
        if (cfg_globalShortcut === hotkey.sequence && !hotkey.paused)
            return hotkey.status || (hotkey.registered ? "Ativo." : "")
        const problem = hotkey.check(cfg_globalShortcut)
        return problem || "Livre. Clique em Aplicar ou OK para usar."
    }
    readonly property bool shortcutOk: shortcutMessage === "Ativo." || shortcutMessage.startsWith("Livre")
    function keyName(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24) return "F" + (key - Qt.Key_F1 + 1)
        if (key === Qt.Key_Space) return "Espaço"
        return ""
    }
    function modifierNames(mods) {
        const out = []
        if (mods & Qt.ControlModifier) out.push("Ctrl")
        if (mods & Qt.ShiftModifier) out.push("Shift")
        if (mods & Qt.AltModifier) out.push("Alt")
        if (mods & Qt.MetaModifier) out.push("Win")
        return out
    }

    // Cofre de credenciais (Windows). Definidos pela SettingsWindow ao carregar a página.
    // Sem cofre (outras plataformas), a chave segue no campo cfg_customApiKey, como antes.
    property var credentials: null
    property string credentialTarget: ""
    readonly property bool vaultSupported: !!credentials && credentials.supported
    property bool keySaved: false
    function refreshKey() { keySaved = vaultSupported && credentials.exists(credentialTarget) }
    // Apaga o que foi digitado e não salvo (chamado ao abrir e ao fechar a janela).
    function resetSecrets() { newApiKey.clear() }

    // Endereço sem https:// (exceto localhost): a chave e as mensagens iriam sem criptografia.
    function insecureUrl(url) {
        const s = String(url || "").trim().toLowerCase()
        if (s === "" || s.startsWith("https://")) return false
        const m = s.match(/^[a-z][a-z0-9+.-]*:\/\/(\[[^\]]+\]|[^\/:?#]+)/)
        const host = m ? m[1] : ""
        return !(host === "localhost" || host === "127.0.0.1" || host === "[::1]")
    }

    property var results: []
    property string searchError: ""
    property bool searching: false

    readonly property var providerOptions: [
        {value: "antigravity", text: "Antigravity — Google DeepMind (agy)"},
        {value: "claude", text: "Claude — Anthropic (claude)"},
        {value: "codex", text: "Codex — OpenAI (codex)"},
        {value: "gemini", text: "Gemini CLI — Google (gemini)"},
        {value: "ollama", text: "Ollama — modelos locais (localhost:11434)"},
        {value: "custom", text: "API Compatível — OpenAI / OpenRouter / Groq / LM Studio"}
    ]
    readonly property var providerModelMap: ({
        antigravity: [
            {value: "gemini-4-argon", text: "Gemini 4 Argon — mais inteligente (recomendado)"},
            {value: "gemini-3.8-flash", text: "Gemini 3.8 Flash — mais rápido"},
            {value: "claude-opus-5-5", text: "Claude Opus 5.5 (Thinking)"},
            {value: "claude-sonnet-5-5", text: "Claude Sonnet 5.5"},
            {value: "gpt-oss-120b", text: "GPT-OSS 120B"}
        ],
        claude: [
            {value: "sonnet", text: "Sonnet — equilibrado (recomendado)"},
            {value: "opus", text: "Opus — mais inteligente"},
            {value: "fable", text: "Fable — tarefas mais difíceis"},
            {value: "haiku", text: "Haiku — mais rápido"}
        ],
        codex: [
            {value: "gpt-5.4", text: "GPT-5.4 — principal (recomendado)"},
            {value: "gpt-5.3-codex", text: "GPT-5.3 Codex — especializado em código"},
            {value: "o4-mini", text: "o4-mini — raciocínio rápido"}
        ],
        gemini: [
            {value: "gemini-2.5-pro", text: "Gemini 2.5 Pro — mais inteligente"},
            {value: "gemini-2.5-flash", text: "Gemini 2.5 Flash — mais rápido"}
        ],
        ollama: [
            {value: "llama3.2", text: "Llama 3.2 (detectado automaticamente no chat)"},
            {value: "qwen2.5-coder", text: "Qwen 2.5 Coder"},
            {value: "deepseek-r1", text: "DeepSeek R1"}
        ],
        custom: [
            {value: "gpt-4o", text: "GPT-4o"},
            {value: "gpt-4o-mini", text: "GPT-4o mini"},
            {value: "claude-3.7-sonnet", text: "Claude 3.7 Sonnet (OpenRouter)"},
            {value: "deepseek-chat", text: "DeepSeek V3"}
        ]
    })
    readonly property var modelOptions: providerModelMap[page.cfg_defaultProvider] || providerModelMap.claude
    readonly property var effortOptions: [
        {value: "low", text: "Baixo"}, {value: "medium", text: "Médio"}, {value: "high", text: "Alto"},
        {value: "xhigh", text: "Extra alto"}, {value: "max", text: "Máximo"}
    ]
    readonly property var topicOptions: [
        {value: "", text: "Principais"}, {value: "NATION", text: "Brasil"}, {value: "WORLD", text: "Mundo"},
        {value: "TECHNOLOGY", text: "Tecnologia"}, {value: "BUSINESS", text: "Economia"}, {value: "SPORTS", text: "Esportes"},
        {value: "ENTERTAINMENT", text: "Entretenimento"}, {value: "SCIENCE", text: "Ciência"}, {value: "HEALTH", text: "Saúde"}
    ]
    function indexOf(list, value) { for (let i = 0; i < list.length; ++i) if (list[i].value === value) return i; return 0 }

    function search() {
        const query = cityField.text.trim()
        if (query.length < 2) return
        searching = true; searchError = ""; results = []
        const request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            searching = false
            if (request.status !== 200) { searchError = "Não foi possível buscar agora. Verifique a internet."; return }
            try {
                const found = JSON.parse(request.responseText).results || []
                results = found
                if (!found.length) searchError = "Nenhuma cidade encontrada."
            } catch (e) { searchError = "Resposta inválida do serviço de busca." }
        }
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=6&language=pt&name=" + encodeURIComponent(query))
        request.send()
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            id: userName
            Kirigami.FormData.label: "Seu nome:"
            placeholderText: "Usado na saudação (opcional)"
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Clima" }

        QQC2.CheckBox {
            id: autoLocation
            Kirigami.FormData.label: "Localização:"
            text: "Detectar automaticamente pela rede"
        }
        QQC2.Label {
            Kirigami.FormData.label: "Cidade atual:"
            text: page.cfg_cityName + "  (" + page.cfg_cityLatitude.toFixed(2) + ", " + page.cfg_cityLongitude.toFixed(2) + ")"
            enabled: !autoLocation.checked
        }
        RowLayout {
            Kirigami.FormData.label: "Trocar cidade:"
            enabled: !autoLocation.checked
            QQC2.TextField {
                id: cityField
                placeholderText: "Digite o nome da cidade"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                onAccepted: page.search()
            }
            QQC2.Button { text: "Buscar"; icon.name: "search"; enabled: !page.searching; onClicked: page.search() }
            QQC2.BusyIndicator { running: page.searching; visible: running; Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5 }
        }
        ColumnLayout {
            visible: page.results.length > 0 || page.searchError !== ""
            enabled: !autoLocation.checked
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            QQC2.Label { visible: page.searchError !== ""; text: page.searchError; color: Kirigami.Theme.negativeTextColor }
            Repeater {
                model: page.results
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name + " — " + [modelData.admin1, modelData.country].filter(Boolean).join(", ")
                    icon.name: "mark-location"
                    onClicked: {
                        page.cfg_cityName = modelData.name
                        page.cfg_cityLatitude = modelData.latitude
                        page.cfg_cityLongitude = modelData.longitude
                        page.results = []; cityField.text = ""
                    }
                }
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Assistente de IA" }

        QQC2.ComboBox {
            Kirigami.FormData.label: "IA padrão:"
            model: page.providerOptions; textRole: "text"; valueRole: "value"
            currentIndex: page.indexOf(page.providerOptions, page.cfg_defaultProvider || "antigravity")
            onActivated: {
                page.cfg_defaultProvider = currentValue
                const list = page.providerModelMap[currentValue] || []
                if (list.length > 0) page.cfg_defaultModel = list[0].value
            }
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Modelo padrão:"
            model: page.modelOptions; textRole: "text"; valueRole: "value"
            currentIndex: page.indexOf(page.modelOptions, page.cfg_defaultModel)
            onActivated: page.cfg_defaultModel = currentValue
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Esforço padrão:"
            visible: page.cfg_defaultProvider === "antigravity" || page.cfg_defaultProvider === "claude" || page.cfg_defaultProvider === "codex"
            model: page.effortOptions; textRole: "text"; valueRole: "value"
            currentIndex: page.indexOf(page.effortOptions, page.cfg_defaultEffort)
            onActivated: page.cfg_defaultEffort = currentValue
        }
        QQC2.TextField {
            id: customApiUrl
            visible: page.cfg_defaultProvider === "custom"
            Kirigami.FormData.label: "Endpoint da API:"
            placeholderText: "https://api.openai.com/v1"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            visible: page.cfg_defaultProvider === "custom" && page.insecureUrl(customApiUrl.text)
            text: "Atenção: este endereço não usa https://. A chave da API e as mensagens seriam enviadas sem criptografia."
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.Wrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        // Windows: a chave fica no Gerenciador de Credenciais; o campo nunca mostra a chave salva.
        ColumnLayout {
            visible: page.cfg_defaultProvider === "custom" && page.vaultSupported
            Kirigami.FormData.label: "Chave da API:"
            spacing: 6
            QQC2.Label {
                text: page.keySaved ? "•••••••• salva no Gerenciador de Credenciais do Windows" : "Nenhuma chave salva"
                opacity: 0.8
            }
            RowLayout {
                QQC2.TextField {
                    id: newApiKey
                    placeholderText: page.keySaved ? "Nova chave, para substituir a atual" : "sk-..."
                    echoMode: TextInput.Password
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                }
                QQC2.Button {
                    text: page.keySaved ? "Alterar" : "Salvar"
                    enabled: newApiKey.text.trim() !== ""
                    onClicked: {
                        if (page.credentials.set(page.credentialTarget, newApiKey.text)) newApiKey.clear()
                        page.refreshKey()
                    }
                }
                QQC2.Button {
                    text: "Remover"
                    visible: page.keySaved
                    onClicked: { page.credentials.remove(page.credentialTarget); page.refreshKey() }
                }
            }
            QQC2.Label {
                visible: page.vaultSupported && page.credentials.lastError !== ""
                text: "Não foi possível acessar o cofre: " + (page.credentials ? page.credentials.lastError : "")
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            }
        }
        // Outras plataformas (sem cofre): campo mascarado salvo nas configurações, como antes.
        QQC2.TextField {
            id: customApiKey
            visible: page.cfg_defaultProvider === "custom" && !page.vaultSupported
            Kirigami.FormData.label: "Chave da API:"
            placeholderText: "sk-..."
            echoMode: TextInput.Password
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.TextField {
            id: customModel
            visible: page.cfg_defaultProvider === "custom"
            Kirigami.FormData.label: "ID do modelo (opcional):"
            placeholderText: "Ex.: anthropic/claude-3.7-sonnet, llama-3.3-70b-versatile"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            text: "Você pode alternar entre Antigravity, Claude e outras IAs diretamente no cabeçalho do chat ou com /ia."
            wrapMode: Text.Wrap; opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Notícias" }

        QQC2.ComboBox {
            Kirigami.FormData.label: "Tema:"
            model: page.topicOptions; textRole: "text"; valueRole: "value"
            currentIndex: page.indexOf(page.topicOptions, page.cfg_newsTopic)
            onActivated: page.cfg_newsTopic = currentValue
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Agenda" }

        QQC2.TextArea {
            id: calendarUrls
            Kirigami.FormData.label: "Links iCal (.ics):"
            placeholderText: "https://calendar.google.com/calendar/ical/.../basic.ics"
            wrapMode: TextEdit.NoWrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            Layout.preferredHeight: Kirigami.Units.gridUnit * 4
        }
        QQC2.Label {
            text: "Um link por linha. No Google Agenda: Configurações da agenda → “Endereço secreto no formato iCal”. Esse endereço dá acesso à sua agenda: não o compartilhe. Os eventos aparecem no calendário e atualizam a cada 15 minutos."
            wrapMode: Text.Wrap; opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        Kirigami.Separator { visible: page.hotkeySupported; Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Atalho global" }

        QQC2.TextField {
            id: shortcutField
            visible: page.hotkeySupported
            Kirigami.FormData.label: "Mostrar/ocultar o painel:"
            readOnly: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            text: activeFocus ? (page.capturing ? page.capturing + "+…" : "Pressione a combinação…") : (page.cfg_globalShortcut || "(nenhum)")
            // Durante a captura o atalho atual fica solto, para a combinação chegar aqui.
            onActiveFocusChanged: { page.capturing = ""; if (page.hotkey) page.hotkey.paused = activeFocus }
            Keys.onPressed: event => {
                event.accepted = true
                if (event.key === Qt.Key_Escape) { shortcutField.focus = false; return }
                if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
                    page.cfg_globalShortcut = page.defaultShortcut; shortcutField.focus = false; return
                }
                const mods = page.modifierNames(event.modifiers)
                const key = page.keyName(event.key)
                if (!key) { page.capturing = mods.join("+"); return }   // só modificadores, por enquanto
                page.cfg_globalShortcut = mods.concat([key]).join("+")
                shortcutField.focus = false
            }
        }
        QQC2.Label {
            visible: page.hotkeySupported && page.shortcutMessage !== ""
            text: page.shortcutMessage
            color: page.shortcutOk ? "#5fd38a" : "#ff8a7a"
            wrapMode: Text.Wrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }
        QQC2.Label {
            visible: page.hotkeySupported
            text: "Clique no campo e pressione a combinação (Ctrl, Alt ou Win com uma letra, um número, F1–F24 ou Espaço). Esc cancela; Backspace volta ao padrão (" + page.defaultShortcut + ")."
            wrapMode: Text.Wrap; opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
