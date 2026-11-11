import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
    property alias cfg_showSystem: system.checked
    property alias cfg_showConnections: connections.checked
    property alias cfg_showMedia: media.checked
    property alias cfg_showNetwork: network.checked
    property alias cfg_showCalendar: calendar.checked
    property alias cfg_showReminders: reminders.checked
    property alias cfg_showNews: news.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Cartões visíveis" }
        QQC2.CheckBox { id: weather; Kirigami.FormData.label: "Painel geral:"; text: "Horário, cidade, clima e previsões (sempre visível)"; checked: true; enabled: false }
        QQC2.CheckBox { id: system; Kirigami.FormData.label: "Cartões:"; text: "Sistema (uso, temperaturas e hardware)" }
        QQC2.CheckBox { id: connections; text: "Baterias e dispositivos" }
        QQC2.CheckBox { id: media; text: "Música tocando agora" }
        QQC2.CheckBox { id: network; text: "Rede e internet" }
        QQC2.CheckBox { id: calendar; text: "Calendário" }
        QQC2.CheckBox { id: reminders; text: "Lembretes" }
        QQC2.CheckBox { id: news; text: "Notícias" }
        QQC2.Label {
            text: "O chat com o Claude fica sempre visível. Os cartões restantes ocupam o espaço dos ocultos."
            wrapMode: Text.Wrap; opacity: 0.7
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
