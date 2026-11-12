import QtQuick
import QtQuick.Shapes

// Ícone do clima. Quando animado, as animações (sol girando, nuvem, gotas e raio) são calculadas a
// partir de um único relógio ("phase", em ms) que avança a 15 ou 30 quadros por segundo, e só enquanto a
// janela está em foco. Antes eram animações contínuas do Qt Quick, que faziam a janela inteira ser
// redesenhada a cada quadro da tela (120 por segundo aqui) mesmo minimizada: ~35% de um núcleo.
// As curvas e durações são as mesmas de antes (ver docs/diario/09-uso-de-cpu-windows.md).
Item {
    id: root
    property int code: 0
    property bool animated: true
    readonly property bool sunny: code >= 0 && code <= 2
    readonly property bool cloudy: code > 0
    readonly property bool rain: (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95
    readonly property bool snow: (code >= 71 && code <= 77) || code === 85 || code === 86
    implicitWidth: 42; implicitHeight: 42

    // Anima só com a janela visível e em foco: atrás de outro app, minimizada ou oculta, para.
    readonly property bool live: animated && visible && Window.active
    property real phase: 0          // tempo de animação acumulado (ms); 0 = nunca animou
    property real lastTick: 0
    // Sol e nuvem se movem menos de 1 px por quadro: 15 quadros por segundo bastam. Chuva, neve e raio
    // têm movimentos mais rápidos: 30.
    Timer {
        interval: root.rain || root.snow ? 33 : 66; repeat: true; running: root.live
        onRunningChanged: root.lastTick = Date.now()
        onTriggered: {
            const now = Date.now()
            root.phase += Math.min(now - root.lastTick, 100)   // sem saltos depois de uma pausa
            root.lastTick = now
        }
    }
    // Mesmas curvas das animações antigas.
    function cloudX() { return 6.5 - 1.5 * Math.cos(2 * Math.PI * phase / 4400) }   // 5 ↔ 8, InOutSine, 2,2 s cada lado
    function dropY(index) {
        const pause = index * 170, cycle = pause + 900, t = phase % cycle
        if (t < pause) return phase < cycle ? 26 : 35
        const p = (t - pause) / 700
        return p < 1 ? 26 + 9 * p * p : 35                                          // InQuad, 0,7 s
    }
    function dropOpacity() { const t = phase % 1100; return t < 550 ? .25 + .75 * t / 550 : 1 - .75 * (t - 550) / 550 }
    function flash() {
        const t = phase % 1830
        if (t < 1300) return phase < 1830 ? .85 : .65
        const steps = [[90, .65, 1], [80, 1, .35], [100, .35, 1], [260, 1, .65]]
        let s = t - 1300
        for (const [d, a, b] of steps) { if (s < d) return a + (b - a) * s / d; s -= d }
        return .65
    }

    Item {
        id: sun; objectName: "weatherSun"
        visible: root.sunny; x: root.cloudy ? 1 : 8; y: 3
        width: 26; height: 26
        rotation: (root.phase / 28000 * 360) % 360
        Repeater {
            model: 8
            delegate: Item {
                required property int index
                anchors.fill: parent; rotation: index * 45
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: 2; height: 4; radius: 1; color: "#e5bd65" }
            }
        }
        Rectangle { anchors.centerIn: parent; width: 15; height: 15; radius: 8; color: "#f4cf79" }
    }
    Item {
        id: cloud; objectName: "weatherCloud"
        visible: root.cloudy; x: root.phase > 0 ? root.cloudX() : 6; y: 5; width: 34; height: 20
        Rectangle { x: 2; y: 8; width: 31; height: 12; radius: 6; color: "#c3c9d1" }
        Rectangle { x: 7; y: 3; width: 15; height: 15; radius: 8; color: "#d1d6dd" }
        Rectangle { x: 17; y: 6; width: 13; height: 13; radius: 7; color: "#c3c9d1" }
    }
    Repeater {
        model: root.rain || root.snow ? (root.code >= 95 ? 2 : 3) : 0
        delegate: Rectangle {
            required property int index
            x: root.code >= 95 ? cloud.x + 2 + index * 26 : 11 + index * 9
            y: root.phase > 0 ? root.dropY(index) : 26
            opacity: root.phase > 0 ? root.dropOpacity() : 1
            width: root.snow ? 3 : 2; height: root.snow ? 3 : 5; radius: 1.5; color: "#83b2d6"; rotation: root.snow ? 0 : 15
        }
    }
    Shape {
        objectName: "weatherLightning"
        visible: root.code >= 95
        x: cloud.x + (cloud.width - width) / 2; y: cloud.y + 13
        width: 12; height: 20
        opacity: root.phase > 0 ? root.flash() : .85
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"; fillColor: "#f7ce65"
            PathSvg { path: "M6 0H10L7 7H12L3 20L5 11H0Z" }
        }
    }
}
