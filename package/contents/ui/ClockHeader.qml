import QtQuick
import QtQuick.Layouts

// Relógio grande, saudação e data.
ColumnLayout {
    id: header
    required property var t
    required property var dash
    property string userName
    spacing: 0
    RowLayout {
        spacing: 4
        Text { text: (header.dash.localTime || "--:--:--").slice(0, 5); color: header.t.ink; font.pixelSize: 44; font.weight: Font.Light; font.letterSpacing: -1 }
        Text { text: (header.dash.localTime || "").slice(6, 8); color: header.t.faint; font.pixelSize: 16; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 9 }
    }
    Text { text: (header.dash.greeting || "Olá") + (header.userName ? ", " + header.userName : ""); color: header.t.accent; font.pixelSize: 14; font.weight: Font.DemiBold }
    Text { text: header.dash.localDate || ""; color: header.t.muted; font.pixelSize: 12; Layout.topMargin: 2 }
}
