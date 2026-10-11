import QtQuick
import "../core"
import "Shapes.js" as Shapes

// M3 Expressive индикатор загрузки (порт lucidui/LoadingIndicator.qml): одна
// фигура морфит по последовательности, пока вращается. contained кладёт её на
// диск primaryContainer. Морфинг идёт через ui/MaterialShape.
Item {
    id: li

    property bool running: visible
    property bool contained: false
    property color color: li.contained ? Theme.fgPrimaryContainer : Theme.primary
    readonly property var sequence: ["softBurst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval"]
    // один масштаб для всех фигур, чтобы ни одна не выходила за бокс при вращении
    readonly property real fit: 1 / Math.max.apply(null, li.sequence.map((n) => Math.max.apply(null, Shapes.radii(n))))
    property real t: 0

    implicitWidth: Theme.dp(44)
    implicitHeight: Theme.dp(44)

    NumberAnimation on t {
        running: li.running && li.visible
        from: 0
        to: li.sequence.length
        duration: li.sequence.length * 650
        loops: Animation.Infinite
    }

    Rectangle {
        visible: li.contained
        anchors.fill: parent
        radius: width / 2
        color: Theme.primaryContainer
    }

    MaterialShape {
        id: s

        readonly property int step: Math.floor(li.t) % li.sequence.length
        readonly property real f: li.t - Math.floor(li.t)
        // пружинистое «доедание» до каждой фигуры
        readonly property real e: 1 - Math.pow(1 - Math.min(1, s.f * 1.6), 3)
        readonly property real sz: li.width * (li.contained ? 0.62 : 0.84) * li.fit

        shape: li.sequence[s.step]
        to: li.sequence[(s.step + 1) % li.sequence.length]
        morph: s.e
        color: li.color
        width: s.sz
        height: s.sz
        anchors.centerIn: parent
        rotation: li.t * 140 + s.e * 50
    }

}
