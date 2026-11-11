import QtQuick
import QtQuick.Window
import "../package/contents/ui"
import "../package/contents/ui/bridge" as Backend

// Captura telas do widget fora do Plasma, com dados reais:
//   qml6 tools/preview.qml -- <pasta-de-saída> ["pergunta ao Claude (usa Haiku)"] [--sem-rede] [--editar]
// --sem-rede oculta o cartão de rede (nome do Wi-Fi e IP) para capturas públicas.
Window {
    id: win
    width: 1300; height: 820; visible: true; color: "#0b0c10"
    readonly property var args: { const a = Qt.application.arguments; const i = a.indexOf("--"); return i >= 0 ? a.slice(i + 1) : [] }
    readonly property var positional: args.filter(a => !a.startsWith("--"))
    readonly property string outDir: positional[0] || "."
    readonly property string question: positional[1] || ""
    readonly property bool hideNetwork: args.indexOf("--sem-rede") >= 0
    readonly property bool edit: args.indexOf("--editar") >= 0
    QtObject {
        id: cfg
        property string userName: "Pietro"
        property bool showWeather: true; property bool showSystem: true; property bool showConnections: true
        property bool showCalendar: true
        property bool showMedia: true; property bool showNetwork: !win.hideNetwork; property bool showReminders: true; property bool showNews: true
        property string reminders: '[{"id":"a","text":"Entregar trabalho de cálculo","done":false},{"id":"b","text":"Comprar café","done":true}]'
    }
    Theme { id: theme }
    Backend.ClaudeClient { id: client; Component.onCompleted: start() }
    Backend.DashboardClient { id: dash; Component.onCompleted: { setLocation("Ourinhos", -22.97889, -49.87056); start() } }
    Backend.MediaClient { id: media }
    Backend.NetworkClient { id: net }
    Shell { id: shell; editing: win.edit; anchors.fill: parent; anchors.margins: 10; t: theme; client: client; dash: dash; media: media; net: net; cfg: cfg }

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
    // --tamanhos=LxA,LxA,...  (padrão: largo, médio e estreito)
    readonly property var sizes: {
        const a = win.args.filter(x => x.startsWith("--tamanhos="))
        const list = a.length ? a[0].slice(11).split(",") : ["1300x820", "980x820", "430x760"]
        return list.map(x => x.split("x").map(Number))
    }
    property int sizeIndex: 0
    function shots() { applySize() }
    function applySize() {
        if (sizeIndex >= sizes.length) { Qt.quit(); return }
        win.width = sizes[sizeIndex][0]; win.height = sizes[sizeIndex][1]
        delay.start()
    }
    Timer { id: delay; interval: 900; onTriggered: {
        const name = sizes.length === 3 && !win.args.some(x => x.startsWith("--tamanhos=")) ? ["wide", "medium", "narrow"][win.sizeIndex] : win.width + "x" + win.height
        win.shot(name, () => { win.sizeIndex++; win.applySize() }) } }
}
