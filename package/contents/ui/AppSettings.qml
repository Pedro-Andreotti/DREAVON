import QtCore

// Configurações do DREAVON fora do Plasma: mesmas chaves e padrões de config/main.xml.
// Ficam em <AppDataLocation>/settings.ini; no Windows, com o aplicativo chamado "DREAVON",
// isso é %APPDATA%\DREAVON\settings.ini.
// A chave da API compatível (customApiKey) NÃO fica aqui: vai para o cofre de credenciais do sistema;
// este arquivo guarda só o nome do destino no cofre (customApiKeyTarget).
Settings {
    location: StandardPaths.writableLocation(StandardPaths.AppDataLocation) + "/settings.ini"

    // Geral
    property string userName: ""
    property bool autoLocation: false
    property string cityName: "Ourinhos"
    property real cityLatitude: -22.97889
    property real cityLongitude: -49.87056
    property string defaultProvider: "antigravity"
    property string defaultModel: "sonnet"
    property string defaultEffort: "medium"
    property string customApiUrl: "https://api.openai.com/v1"
    property string customApiKeyTarget: "DREAVON/customApiKey"
    property string customModel: ""
    property string newsTopic: ""
    property string calendarUrls: ""
    // Atalho global para mostrar/ocultar o painel (Windows; ver GlobalHotkey).
    property string globalShortcut: "Ctrl+Shift+Alt+D"

    // Cartões
    property bool showWeather: true
    property bool showSystem: true
    property bool showConnections: true
    property bool showMedia: true
    property bool showNetwork: true
    property bool showCalendar: true
    property bool showReminders: true
    property bool showNews: true

    // Aparência
    property string accentColor: "#2f8bff"
    property int backgroundOpacity: 94
    property bool animations: true

    // Dados
    property string reminders: "[]"
    property string layout: ""
}
