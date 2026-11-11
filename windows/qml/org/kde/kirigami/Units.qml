pragma Singleton
import QtQuick

// Medidas equivalentes às do Kirigami.Units (gridUnit = altura de uma linha de texto).
QtObject {
    readonly property int gridUnit: Math.round(fontMetrics.height)
    readonly property int smallSpacing: 4
    readonly property int mediumSpacing: 6
    readonly property int largeSpacing: 8
    readonly property int shortDuration: 100
    readonly property int longDuration: 200
    property FontMetrics fontMetrics: FontMetrics {}
}
