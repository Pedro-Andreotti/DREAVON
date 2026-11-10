import QtQuick
import QtQuick.Layouts

Card {
    id: card
    required property var dash
    title: dash.weatherLocation || "Clima"
    icon: "weather-few-clouds-symbolic"
    readonly property var today: dash.forecast.length ? dash.forecast[0] : null

    RowLayout {
        spacing: 12
        WeatherIcon { code: card.today ? card.today.code : 0; animated: card.t.animations; Layout.preferredWidth: 46; Layout.preferredHeight: 46 }
        ColumnLayout {
            spacing: 0; Layout.fillWidth: true
            Text { text: card.dash.weatherTemperature || "—"; color: card.t.ink; font.pixelSize: 30; font.weight: Font.Light }
            Text { text: card.dash.weatherSummary || card.dash.weatherStatus; color: card.t.muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        ColumnLayout {
            visible: card.today !== null; spacing: 0
            Text { text: "↑ " + (card.today ? card.today.high : ""); color: card.t.ink; font.pixelSize: 12; Layout.alignment: Qt.AlignRight }
            Text { text: "↓ " + (card.today ? card.today.low : ""); color: card.t.muted; font.pixelSize: 12; Layout.alignment: Qt.AlignRight }
        }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: card.t.border; visible: card.dash.forecast.length > 1 }
    RowLayout {
        visible: card.dash.forecast.length > 1
        spacing: 0; Layout.fillWidth: true
        Repeater {
            model: card.dash.forecast.slice(1)
            delegate: ColumnLayout {
                required property var modelData
                spacing: 2; Layout.fillWidth: true
                Text { text: modelData.day.slice(0, 3); color: card.t.muted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                WeatherIcon { code: modelData.code; animated: false; scale: 0.5; Layout.preferredWidth: 22; Layout.preferredHeight: 22; Layout.alignment: Qt.AlignHCenter; transformOrigin: Item.Center }
                Text { text: modelData.high; color: card.t.ink; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                Text { text: modelData.low; color: card.t.faint; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }
}
