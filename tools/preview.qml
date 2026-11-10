import QtQuick
import QtQuick.Window
import "../package/contents/ui"
import "../package/contents/ui/bridge" as Backend

// Captura telas do widget fora do Plasma, com dados reais:
//   qml6 tools/preview.qml -- <pasta-de-saída> ["pergunta ao Claude (usa Haiku)"] [--sem-rede]
// --sem-rede oculta o cartão de rede (nome do Wi-Fi e IP) para capturas públicas.
Window {
    id: win
    width: 1180; height: 720; visible: true; color: "#0b0c10"
    readonly property var args: { const a = Qt.application.arguments; const i = a.indexOf("--"); return i >= 0 ? a.slice(i + 1) : [] }
    readonly property var positional: args.filter(a => !a.startsWith("--"))
    readonly property string outDir: positional[0] || "."
    readonly property string question: positional[1] || ""
    readonly property bool hideNetwork: args.indexOf("--sem-rede") >= 0
    QtObject {
        id: cfg
        property string userName: "Pietro"
        property bool showWeather: true; property bool showSystem: true; property bool showConnections: true
        property bool showMedia: true; property bool showNetwork: !win.hideNetwork; property bool showReminders: true; property bool showNews: true
        property string reminders: '[{"id":"a","text":"Entregar trabalho de cálculo","done":false},{"id":"b","text":"Comprar café","done":true}]'
    }
    Theme { id: theme }
    Backend.ClaudeClient { id: client; Component.onCompleted: start() }
    Backend.DashboardClient { id: dash; Component.onCompleted: { setLocation("Ourinhos", -22.97889, -49.87056); start() } }
    Backend.MediaClient { id: media }
    Backend.NetworkClient { id: net }
    Shell { id: shell; anchors.fill: parent; anchors.margins: 10; t: theme; client: client; dash: dash; media: media; net: net; cfg: cfg }

    property int stage: 0
    function shot(name, next) { win.contentItem.grabToImage(r => { r.saveToFile(outDir + "/" + name + ".png"); console.log("SHOT", name); next() }) }
    Timer {
        interval: 9000; running: true
        onTriggered: {
            if (win.question && client.ready) { client.model = "haiku"; client.effort = "low"; client.send(win.question); waitReply.start() }
            else win.shots()
        }
    }
    Timer { id: waitReply; interval: 500; repeat: true; onTriggered: if (!client.busy) { stop(); win.shots() } }
    function shots() {
        shot("wide", () => { win.width = 900; Qt.callLater(() => delay.start()) })
    }
    Timer { id: delay; interval: 800; onTriggered: win.shot("medium", () => { win.width = 430; win.height = 760; delay2.start() }) }
    Timer { id: delay2; interval: 800; onTriggered: win.shot("narrow", () => Qt.quit()) }
}
