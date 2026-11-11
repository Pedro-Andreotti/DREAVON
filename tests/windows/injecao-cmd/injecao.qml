import QtQuick
import "../../../package/contents/ui/bridge" as Backend

// Testes de injeção de comandos pelo cmd.exe (passo 3). Rodado por injecao.ps1, com o cenário
// como último argumento:
//   A: CLI só disponível como .cmd desconhecido -> a mensagem hostil vai pelo stdin, nunca como argumento.
//   B: o mesmo .cmd com um anexo cujo nome tem & % ! -> o DREAVON recusa executar.
//   C: shim do npm que aponta para um .js -> roda "node script.js" direto, sem cmd.exe.
Item {
    readonly property string dir: Qt.resolvedUrl(".").toString().replace("file:///", "").replace(/\/$/, "")
    readonly property string scenario: Qt.application.arguments[Qt.application.arguments.length - 1]
    // Mensagem hostil: aspas, &, |, %, ^, !, redirecionamento e quebra de linha.
    readonly property string hostile: 'teste "aspas" & echo INJETADO > "' + dir.replace(/\//g, "\\") + '\\pwned.txt" | type %PATH% ^ !x!\nlinha 2 & del *.*'
    Backend.ClaudeClient {
        id: client
        provider: "codex"
        executable: scenario === "C" ? dir + "/npmlike/fakecli.cmd" : dir + "/codex.cmd"
    }
    Component.onCompleted: client.start()
    Timer {
        interval: 1500; running: true
        onTriggered: {
            if (scenario === "B") console.log("ANEXO", client.addAttachment("file:///" + dir + "/foto & echo INJETADO %PATH% !.png"))
            console.log("ENVIO", client.send(scenario === "B" ? "mensagem simples" : parent.hostile))
        }
    }
    Timer {
        interval: 6000; running: true
        onTriggered: { console.log("ERRO", client.error); console.log("BUSY", client.busy); Qt.quit() }
    }
}
