pragma ComponentBehavior: Bound
import QtQuick
import "../../core"

// Самостоятельный визуализатор на рабочем столе: бары core/Cava с собственным
// uid (MediaCard держит "card" — не спорим за него). Показывается слоем только
// при воспроизведении (claim в WidgetLayer), а здесь — правило want/drop.
Rectangle {
    id: w

    color: Theme.withBlur(Theme.mHigh)
    radius: Theme.shapeLgInc
    clip: true
    implicitWidth: Theme.dp(296)
    implicitHeight: viz.implicitHeight + Theme.dp(28)

    readonly property string cavaUid: "vizwidget"
    readonly property int vizBars: Math.max(8, Math.min(40, Math.floor((w.vizWidth + Theme.dp(3)) / Theme.dp(11))))
    readonly property real vizWidth: Math.max(0, w.width - Theme.dp(28))

    Component.onCompleted: w.syncCava()
    onVisibleChanged: w.syncCava()
    Component.onDestruction: Cava.drop(w.cavaUid)
    onVizBarsChanged: w.syncCava()

    function syncCava() {
        Cava.want(w.cavaUid, w.vizBars);
    }

    Item {
        id: viz

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.dp(14)
        implicitHeight: Theme.dp(56)

        readonly property real slot: (viz.width - (w.vizBars - 1) * Theme.dp(3)) / w.vizBars

        Row {
            anchors.fill: parent
            spacing: Theme.dp(3)

            Repeater {
                model: w.vizBars

                Rectangle {
                    required property int index

                    readonly property real level: (Cava.levels[index] !== undefined) ? Cava.levels[index] : 0

                    width: viz.slot
                    height: Math.min(viz.implicitHeight, Math.max(viz.slot, level * viz.implicitHeight))
                    anchors.bottom: parent.bottom
                    radius: viz.slot / 2
                    color: viz.barColor(level)

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.ms(70)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

        function barColor(level) {
            // тишина — акцент-контейнер, бит — акцент (как в MediaCard)
            var f = 0.62;
            var k = f + (1 - f) * Math.min(1, level * 1.25);
            return Qt.rgba(Theme.accentContainer.r * (1 - k) + Theme.accent.r * k, Theme.accentContainer.g * (1 - k) + Theme.accent.g * k, Theme.accentContainer.b * (1 - k) + Theme.accent.b * k, 1);
        }

    }

}
