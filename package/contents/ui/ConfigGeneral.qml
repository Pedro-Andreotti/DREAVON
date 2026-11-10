import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page
    property alias cfg_userName: userName.text
    property alias cfg_autoLocation: autoLocation.checked
    property string cfg_cityName
    property real cfg_cityLatitude
    property real cfg_cityLongitude
    property string cfg_defaultModel
    property string cfg_defaultEffort
    property string cfg_newsTopic

    property var results: []
    property string searchError: ""
    property bool searching: false

    readonly property var modelOptions: [
        {value: "sonnet", text: "Sonnet — equilibrado (recomendado)"},
        {value: "opus", text: "Opus — mais inteligente"},
        {value: "fable", text: "Fable — tarefas mais difíceis"},
        {value: "haiku", text: "Haiku — mais rápido"}
    ]
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

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Claude" }

        QQC2.ComboBox {
            Kirigami.FormData.label: "Modelo padrão:"
            model: page.modelOptions; textRole: "text"; valueRole: "value"
            currentIndex: page.indexOf(page.modelOptions, page.cfg_defaultModel)
            onActivated: page.cfg_defaultModel = currentValue
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Esforço padrão:"
            model: page.effortOptions; textRole: "text"; valueRole: "value"
            currentIndex: page.indexOf(page.effortOptions, page.cfg_defaultEffort)
            onActivated: page.cfg_defaultEffort = currentValue
        }
        QQC2.Label {
            text: "Mais esforço deixa as respostas mais cuidadosas, porém mais lentas e consome mais cota."
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
    }
}
