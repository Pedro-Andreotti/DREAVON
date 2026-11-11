import QtQuick
import QtQuick.Layouts

// Calendário do mês com navegação; hoje destacado.
Card {
    id: card
    title: monthNames[shown.getMonth()] + " " + shown.getFullYear()
    icon: "view-calendar-symbolic"
    stretch: true
    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    property date today: new Date()
    property date shown: new Date(today.getFullYear(), today.getMonth(), 1)
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { const n = new Date(); if (n.getDate() !== card.today.getDate()) card.today = n } }

    readonly property var cells: {
        const first = new Date(shown.getFullYear(), shown.getMonth(), 1)
        const start = new Date(first); start.setDate(1 - first.getDay())
        const list = []
        for (let i = 0; i < 42; ++i) {
            const d = new Date(start); d.setDate(start.getDate() + i)
            list.push({day: d.getDate(), inMonth: d.getMonth() === shown.getMonth(),
                       isToday: d.toDateString() === today.toDateString(), weekend: d.getDay() === 0 || d.getDay() === 6})
        }
        // Remove a última semana quando ela é toda do mês seguinte.
        return list[35].inMonth ? list : list.slice(0, 35)
    }
    readonly property string footer: {
        const startOfYear = new Date(today.getFullYear(), 0, 1)
        const dayOfYear = Math.floor((today - startOfYear) / 86400000) + 1
        const daysInYear = (new Date(today.getFullYear(), 1, 29).getMonth() === 1) ? 366 : 365
        const week = Math.ceil((dayOfYear + startOfYear.getDay()) / 7)
        return "Semana " + week + " · dia " + dayOfYear + " de " + daysInYear
    }
    function move(delta) { shown = new Date(shown.getFullYear(), shown.getMonth() + delta, 1) }

    actions: [
        IconButton { t: card.t; icon: "go-previous"; size: 22; tip: "Mês anterior"; onClicked: card.move(-1) },
        IconButton { t: card.t; icon: "go-jump-today"; size: 22; tip: "Hoje"; onClicked: card.shown = new Date(card.today.getFullYear(), card.today.getMonth(), 1) },
        IconButton { t: card.t; icon: "go-next"; size: 22; tip: "Próximo mês"; onClicked: card.move(1) }
    ]

    GridLayout {
        Layout.fillWidth: true; Layout.fillHeight: true
        columns: 7; columnSpacing: 0; rowSpacing: 0
        Repeater {
            model: ["D", "S", "T", "Q", "Q", "S", "S"]
            delegate: Text {
                required property string modelData
                text: modelData; color: card.t.faint; font.pixelSize: 10; font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; Layout.preferredHeight: 18
            }
        }
        Repeater {
            model: card.cells
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredHeight: 22; Layout.minimumHeight: 20; Layout.maximumHeight: 40
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height, 26); height: width; radius: width / 2
                    color: modelData.isToday ? card.t.accent : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.day
                    font.pixelSize: 11; font.weight: modelData.isToday ? Font.Bold : Font.Normal
                    color: modelData.isToday ? "#0b0f18" : !modelData.inMonth ? Qt.rgba(1, 1, 1, 0.18) : modelData.weekend ? card.t.muted : card.t.ink
                }
            }
        }
    }
    Text { text: card.footer; color: card.t.faint; font.pixelSize: 10 }
}
