import QtQuick

// Gráfico de linha simples com área preenchida; aceita uma ou duas séries.
Canvas {
    id: chart
    property var values: []
    property var secondary: []
    property color color: "#8b7cff"
    property color secondaryColor: "#5fd38a"
    implicitHeight: 46
    onValuesChanged: requestPaint()
    onSecondaryChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d"); ctx.reset()
        const all = values.concat(secondary)
        const top = Math.max(1, Math.max.apply(null, all.length ? all : [1])) * 1.15
        const draw = function(series, color, fill) {
            if (series.length < 2) return
            const step = width / (series.length - 1)
            ctx.beginPath()
            for (let i = 0; i < series.length; ++i) {
                const x = i * step, y = height - (series[i] / top) * (height - 2) - 1
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.strokeStyle = color; ctx.lineWidth = 1.6; ctx.stroke()
            if (fill) {
                ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                const g = ctx.createLinearGradient(0, 0, 0, height)
                g.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.35)); g.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0))
                ctx.fillStyle = g; ctx.fill()
            }
        }
        draw(secondary, secondaryColor, false)
        draw(values, color, true)
    }
}
