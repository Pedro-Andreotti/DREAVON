import QtQml

// Ponto de entrada no Windows durante o desenvolvimento, aberto pelo qml.exe do Qt (assinado),
// porque o Controle Inteligente de Aplicativos bloqueia executáveis próprios sem assinatura.
//   qml.exe --apptype widget -I windows/qml windows/dreavon.qml
// (ou .\build-windows.ps1 -Run). Define o nome do aplicativo antes de abrir a janela, para as
// configurações ficarem em %APPDATA%\DREAVON.
QtObject {
    id: entry
    property var window: null
    Component.onCompleted: {
        Qt.application.name = "DREAVON"
        Qt.application.organization = ""
        const component = Qt.createComponent(Qt.resolvedUrl("../package/contents/ui/main.qml"))
        if (component.status !== Component.Ready) {
            console.error(component.errorString())
            Qt.exit(1)
            return
        }
        // "-- --bandeja" (início com o Windows): abre só na bandeja, sem mostrar a janela.
        const tray = Qt.application.arguments.indexOf("--bandeja") >= 0
        entry.window = tray ? component.createObject(null, {visible: false}) : component.createObject(null)
    }
}
