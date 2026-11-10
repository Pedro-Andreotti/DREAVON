import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Painel geral: horário, cidade, temperatura de hoje com detalhes, próximas horas e próximos dias.
// mode: "full" (tudo em linha), "compact" (agora em cima, previsões embaixo), "stacked" (coluna estreita).
Rectangle {
    id: hero
    required property var t
    required property var dash
    property string userName
    property string mode: "full"
    readonly property var w: dash.weatherDetails || ({})
    readonly property var today: dash.forecast.length ? dash.forecast[0] : null

    radius: t.radius + 4
    border.color: t.border
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.rgba(hero.t.accent.r, hero.t.accent.g, hero.t.accent.b, 0.20) }
        GradientStop { position: 0.45; color: hero.t.card }
        GradientStop { position: 1; color: hero.t.card }
    }
    implicitHeight: grid.implicitHeight + 32

    function uvLabel(uv) { return uv < 0 ? "" : uv <= 2 ? "baixo" : uv <= 5 ? "moderado" : uv <= 7 ? "alto" : uv <= 10 ? "muito alto" : "extremo" }
    function deg(v) { return v > -999 ? v + "°" : "—" }

    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.margins: 16
        columns: hero.mode === "full" ? 5 : hero.mode === "compact" ? 3 : 1
        columnSpacing: 20; rowSpacing: 14

        // Relógio
        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: hero.mode === "stacked" ? -1 : 210
            RowLayout {
                spacing: 4
                Text { text: (hero.dash.localTime || "--:--").slice(0, 5); color: hero.t.ink; font.pixelSize: 58; font.weight: Font.Light; font.letterSpacing: -2 }
                Text { text: (hero.dash.localTime || "").slice(6, 8); color: hero.t.faint; font.pixelSize: 18; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 12 }
            }
            Text { text: (hero.dash.greeting || "Olá") + (hero.userName ? ", " + hero.userName : ""); color: hero.t.accent; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { text: hero.dash.localDate || ""; color: hero.t.muted; font.pixelSize: 12; Layout.topMargin: 2 }
        }

        Rectangle { visible: hero.mode !== "stacked"; Layout.fillHeight: true; width: 1; color: hero.t.border }

        // Agora
        ColumnLayout {
            spacing: 8
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: hero.mode === "stacked" ? -1 : 330
            Layout.fillWidth: hero.mode !== "full"
            RowLayout {
                spacing: 12
                Item {
                    Layout.preferredWidth: 64; Layout.preferredHeight: 64
                    WeatherIcon { anchors.centerIn: parent; scale: 1.45; code: hero.w.code !== undefined ? hero.w.code : (hero.today ? hero.today.code : 0); animated: hero.t.animations }
                }
                ColumnLayout {
                    spacing: 0
                    RowLayout {
                        spacing: 6
                        Text { text: hero.dash.weatherTemperature || "—"; color: hero.t.ink; font.pixelSize: 44; font.weight: Font.Light }
                        ColumnLayout {
                            spacing: 0; Layout.alignment: Qt.AlignVCenter
                            Text { text: "↑ " + hero.deg(hero.w.high); color: hero.t.ink; font.pixelSize: 12 }
                            Text { text: "↓ " + hero.deg(hero.w.low); color: hero.t.muted; font.pixelSize: 12 }
                        }
                    }
                    RowLayout {
                        spacing: 4
                        Kirigami.Icon { source: "mark-location-symbolic"; implicitWidth: 14; implicitHeight: 14; isMask: true; color: hero.t.accent }
                        Text { text: hero.dash.weatherLocation || "—"; color: hero.t.ink; font.pixelSize: 15; font.weight: Font.DemiBold }
                    }
                    Text {
                        text: (hero.dash.weatherSummary || "").split(" · ")[0] || hero.dash.weatherStatus
                        color: hero.t.muted; font.pixelSize: 12
                    }
                }
            }
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: [
                        {icon: "temperature-normal", text: "Sensação " + hero.deg(hero.w.feelsLike), show: hero.w.feelsLike > -999},
                        {icon: "raindrop", text: "Umidade " + hero.w.humidity + "%", show: hero.w.humidity >= 0},
                        {glyph: "≈", text: "Vento " + hero.w.wind + " km/h " + (hero.w.windDirection || ""), show: hero.w.wind >= 0},
                        {icon: "weather-showers-scattered-symbolic", text: "Chuva " + hero.w.rainChance + "%", show: hero.w.rainChance >= 0},
                        {icon: "weather-clear-symbolic", text: "UV " + hero.w.uv + " · " + hero.uvLabel(hero.w.uv), show: hero.w.uv >= 0},
                        {glyph: "☀", text: "Sol " + (hero.w.sunrise || "") + " – " + (hero.w.sunset || ""), show: !!hero.w.sunrise}
                    ].filter(c => c.show)
                    delegate: Rectangle {
                        required property var modelData
                        height: 24; width: chipRow.implicitWidth + 16; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05); border.color: hero.t.border
                        Row {
                            id: chipRow; anchors.centerIn: parent; spacing: 5
                            Kirigami.Icon { visible: !!modelData.icon; source: modelData.icon || ""; width: 13; height: 13; isMask: true; color: hero.t.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { visible: !!modelData.glyph; text: modelData.glyph || ""; color: hero.t.accent; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.text; color: hero.t.ink; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        Rectangle { visible: hero.mode === "full"; Layout.fillHeight: true; width: 1; color: hero.t.border }

        // Próximas horas + próximos dias
        ColumnLayout {
            Layout.fillWidth: true
            Layout.columnSpan: hero.mode === "compact" ? 3 : 1
            Layout.alignment: Qt.AlignTop
            spacing: 6
            Text { text: "PRÓXIMAS HORAS"; color: hero.t.muted; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
            RowLayout {
                Layout.fillWidth: true; spacing: 0
                Repeater {
                    model: hero.mode === "stacked" ? hero.dash.hourly.slice(0, 6) : hero.dash.hourly
                    // Cada hora é um Item que estica, com o conteúdo centralizado (layouts aninhados não esticam sozinhos).
                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitWidth: hourCol.implicitWidth; implicitHeight: hourCol.implicitHeight
                        ColumnLayout {
                        id: hourCol; anchors.horizontalCenter: parent.horizontalCenter; spacing: 1
                        Text { text: modelData.now ? "Agora" : modelData.hour; color: modelData.now ? hero.t.accent : hero.t.muted; font.pixelSize: 10; font.weight: modelData.now ? Font.DemiBold : Font.Normal; Layout.alignment: Qt.AlignHCenter }
                        Item { Layout.preferredWidth: 24; Layout.preferredHeight: 22; Layout.alignment: Qt.AlignHCenter
                            WeatherIcon { anchors.centerIn: parent; code: modelData.code; animated: false; scale: 0.52 } }
                        Text { text: modelData.temp + "°"; color: hero.t.ink; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
                        Text { text: modelData.rain > 0 ? modelData.rain + "%" : " "; color: "#7cc4ff"; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: hero.t.border }
            Text { text: "PRÓXIMOS DIAS"; color: hero.t.muted; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
            RowLayout {
                Layout.fillWidth: true; spacing: 0
                Repeater {
                    model: hero.mode === "stacked" ? hero.dash.forecast.slice(1, 5) : hero.dash.forecast.slice(1)
                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitWidth: dayRow.implicitWidth; implicitHeight: dayRow.implicitHeight
                        RowLayout {
                        id: dayRow; anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
                        Item { Layout.preferredWidth: 22; Layout.preferredHeight: 22
                            WeatherIcon { anchors.centerIn: parent; code: modelData.code; animated: false; scale: 0.52 } }
                        ColumnLayout {
                            spacing: 0
                            Text { text: modelData.day.slice(0, 3); color: hero.t.muted; font.pixelSize: 10 }
                            Text { text: modelData.high + " " + modelData.low; color: hero.t.ink; font.pixelSize: 11 }
                            Text { visible: modelData.rain > 0; text: modelData.rain + "%"; color: "#7cc4ff"; font.pixelSize: 9 }
                        }
                        }
                    }
                }
            }
        }
    }
}
