import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showWeather: weather.checked
    property alias cfg_showSystem: system.checked
    property alias cfg_showConnections: connections.checked
    property alias cfg_showMedia: media.checked
    property alias cfg_showNetwork: network.checked
    property alias cfg_showReminders: reminders.checked
    property alias cfg_showNews: news.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Cartões visíveis" }
        QQC2.CheckBox { id: weather; Kirigami.FormData.label: "Coluna da esquerda:"; text: "Clima e previsão de 7 dias" }
        QQC2.CheckBox { id: system; text: "Sistema (CPU, GPU, memória e disco)" }
        QQC2.CheckBox { id: connections; text: "Baterias e dispositivos" }
        QQC2.CheckBox { id: media; Kirigami.FormData.label: "Coluna da direita:"; text: "Música tocando agora" }
        QQC2.CheckBox { id: network; text: "Rede e internet" }
        QQC2.CheckBox { id: reminders; text: "Lembretes" }
        QQC2.CheckBox { id: news; text: "Notícias" }
        QQC2.Label {
            text: "O chat com o Claude fica sempre visível. Com uma coluna vazia, o chat ocupa o espaço."
            wrapMode: Text.Wrap; opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
