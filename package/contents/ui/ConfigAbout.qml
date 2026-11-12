import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "bridge" as Backend

// Configurações > Sobre: versão (de project(VERSION) no CMakeLists.txt, pelo plugin), créditos e licenças.
ConfigPage {
    id: page
    readonly property string version: Backend.AppInfo.version || "—"
    readonly property string repository: Backend.AppInfo.repository

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "DREAVON" }

        QQC2.Label {
            Kirigami.FormData.label: "Versão:"
            text: "DREAVON " + page.version
            font.weight: Font.DemiBold
        }
        QQC2.Label {
            Kirigami.FormData.label: "Edição:"
            text: "Uso pessoal no Windows (sem instalador nem assinatura)"
        }
        QQC2.Label {
            Kirigami.FormData.label: "Repositório:"
            text: "<a href=\"" + page.repository + "\">" + page.repository.replace("https://", "") + "</a>"
            textFormat: Text.StyledText
            onLinkActivated: link => Qt.openUrlExternally(link)
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Créditos" }

        QQC2.Label {
            text: "O DREAVON é uma adaptação do Plasdria (© Pietro Alexandria, licença MIT), um widget para o KDE Plasma, que inclui código do PRAGUS (MIT). Os avisos de copyright originais estão no arquivo LICENSE."
            wrapMode: Text.Wrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Licenças" }

        QQC2.Label {
            Kirigami.FormData.label: "DREAVON:"
            text: "MIT"
        }
        QQC2.Label {
            Kirigami.FormData.label: "Qt 6:"
            text: "LGPL-3.0 (bibliotecas usadas sem modificação, por ligação dinâmica)"
            wrapMode: Text.Wrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        }
        QQC2.Label {
            Kirigami.FormData.label: "Ícones Breeze:"
            text: "LGPL-3.0-or-later (© Uri Herrera e outros; aviso em COPYING-ICONS)"
            wrapMode: Text.Wrap
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        }
        QQC2.Label {
            text: "Projeto independente, sem afiliação com a Anthropic, a Microsoft, o KDE, a Qt Company ou os provedores de dados."
            wrapMode: Text.Wrap; opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
