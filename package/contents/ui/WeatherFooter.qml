import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Rodapé do clima: detalhes de hoje, próximas horas e a semana.
// compact: empilha as três partes (layouts médio e estreito).
Rectangle {
    id: footer
    required property var t
    required property var dash
    property bool compact: false
    readonly property var w: dash.weatherDetails || ({})

    radius: t.radius
    color: t.card
    border.color: t.border
    implicitHeight: layout.implicitHeight + 20

    function deg(v) { return v > -999 ? v + "°" : "—" }
    function uvLabel(uv) { return uv < 0 ? "" : uv <= 2 ? "baixo" : uv <= 5 ? "moderado" : uv <= 7 ? "alto" : uv <= 10 ? "muito alto" : "extremo" }

    // Largura mínima de cada coluna (horas e dias), medida com os textos mais longos possíveis, para as
    // colunas terem a mesma largura e nunca encostarem uma na outra, em qualquer escala de exibição.
    TextMetrics { id: tempMetrics; font.pixelSize: 11; text: "-10° -10°" }
    TextMetrics { id: hourMetrics; font.pixelSize: 11; text: "-10°" }
    TextMetrics { id: rainMetrics; font.pixelSize: 9; text: "☂ 100%" }
    readonly property real hourWidth: Math.max(hourMetrics.advanceWidth, rainMetrics.advanceWidth, 26) + 4
    readonly property real dayWidth: Math.max(tempMetrics.advanceWidth, rainMetrics.advanceWidth, 26) + 4

    component Heading: Text { color: footer.t.muted; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }

    GridLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 14; anchors.rightMargin: 14
        columns: footer.compact ? 1 : 5
        columnSpacing: 16; rowSpacing: 10

        // Hoje em detalhes
        ColumnLayout {
            spacing: 4
            Layout.preferredWidth: footer.compact ? -1 : 300
            Layout.alignment: Qt.AlignTop
            Heading { text: "HOJE EM " + (footer.dash.weatherLocation || "").toUpperCase() }
            GridLayout {
                columns: 2; columnSpacing: 14; rowSpacing: 2
                Repeater {
                    model: [
                        ["Sensação", footer.deg(footer.w.feelsLike)],
                        ["Umidade", footer.w.humidity >= 0 ? footer.w.humidity + "%" : "—"],
                        ["Vento", footer.w.wind >= 0 ? footer.w.wind + " km/h " + (footer.w.windDirection || "") : "—"],
                        ["Chuva", footer.w.rainChance >= 0 ? footer.w.rainChance + "%" : "—"],
                        ["UV", footer.w.uv >= 0 ? footer.w.uv + " · " + footer.uvLabel(footer.w.uv) : "—"],
                        ["Sol", footer.w.sunrise ? footer.w.sunrise + " – " + footer.w.sunset : "—"]
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 6
                        Text { text: modelData[0]; color: footer.t.faint; font.pixelSize: 11; Layout.preferredWidth: 58 }
                        Text { text: modelData[1]; color: footer.t.ink; font.pixelSize: 11 }
                    }
                }
            }
        }

        Rectangle { visible: !footer.compact; Layout.fillHeight: true; width: 1; color: footer.t.border }

        // Próximas horas
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true; Layout.preferredWidth: 2
            Layout.alignment: Qt.AlignTop
            Heading { text: "PRÓXIMAS HORAS" }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: footer.dash.hourly.slice(0, footer.compact ? 6 : 8)
                    delegate: Item {
                        required property var modelData
                        // Colunas de largura igual, com mínimo para o texto mais longo.
                        Layout.fillWidth: true
                        Layout.minimumWidth: footer.hourWidth; Layout.preferredWidth: footer.hourWidth
                        implicitHeight: hourCol.implicitHeight
                        ColumnLayout {
                            id: hourCol; anchors.horizontalCenter: parent.horizontalCenter; spacing: 0
                            Text { text: modelData.now ? "Agora" : modelData.hour; color: modelData.now ? footer.t.accent : footer.t.muted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                            Item { Layout.preferredWidth: 22; Layout.preferredHeight: 20; Layout.alignment: Qt.AlignHCenter
                                WeatherIcon { anchors.centerIn: parent; code: modelData.code; animated: false; scale: 0.48 } }
                            // Temperatura em cima e chance de chuva embaixo, no mesmo estilo da semana.
                            Text { text: modelData.temp + "°"; color: footer.t.ink; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                            Text { text: modelData.rain > 20 ? "☂ " + modelData.rain + "%" : " "; color: "#7cc4ff"; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }
        }

        Rectangle { visible: !footer.compact; Layout.fillHeight: true; width: 1; color: footer.t.border }

        // Semana
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true; Layout.preferredWidth: 3
            Layout.alignment: Qt.AlignTop
            Heading { text: "SEMANA" }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: footer.compact ? footer.dash.forecast.slice(0, 5) : footer.dash.forecast
                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: footer.dayWidth; Layout.preferredWidth: footer.dayWidth
                        implicitHeight: dayCol.implicitHeight
                        ColumnLayout {
                            id: dayCol; anchors.horizontalCenter: parent.horizontalCenter; spacing: 0
                            Text { text: modelData.isToday ? "Hoje" : modelData.day.slice(0, 3); color: modelData.isToday ? footer.t.accent : footer.t.muted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                            Item { Layout.preferredWidth: 22; Layout.preferredHeight: 20; Layout.alignment: Qt.AlignHCenter
                                WeatherIcon { anchors.centerIn: parent; code: modelData.code; animated: false; scale: 0.48 } }
                            Text { text: modelData.high + " " + modelData.low; color: footer.t.ink; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                            Text { text: modelData.rain > 0 ? "☂ " + modelData.rain + "%" : " "; color: "#7cc4ff"; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }
        }
    }
}
