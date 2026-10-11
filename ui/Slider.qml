import QtQuick
import "../core"

// M3-слайдер в стиле «filled material»: толстый pill-трек, заливка акцентом,
// крупная круглая ручка с контрастным кольцом. На ховере/нажатии ручка
// немного масштабируется. Высота 24, зона мыши выше трека.
Item {
    id: root

    // значение 0..1
    property real value: 0
    // значение во время перетаскивания: ручка следует за мышью, даже если
    // вызывающий код не пишет value
    property real live: 0
    // ведём сами, чтобы анимация live не перехватывала запись в onPressed
    // (pressed у MouseArea объявляется после pressedChanged)
    property bool dragging: false
    readonly property bool hovered: area.containsMouse
    readonly property bool hot: root.enabled && (root.hovered || root.dragging)

    signal moved(real v)
    signal committed(real v)

    implicitWidth: Theme.dp(200)
    implicitHeight: Theme.dp(24)
    opacity: root.enabled ? 1 : Theme.disabledContent

    Component.onCompleted: root.live = root.value
    onValueChanged: {
        if (!root.dragging)
            root.live = root.value;
    }

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    // v = x / ширине трека
    function valueAt(px) { return root.clamp01(px / Math.max(1, root.width)) }

    // геометрия «материала»
    readonly property real _trackH: Theme.dp(16)
    readonly property real _thumbD: Theme.dp(22)
    // ручка не вылезает за края трека
    readonly property real _thumbX: Math.max(root._thumbD / 2, Math.min(root.width - root._thumbD / 2, root.live * root.width))

    // значение приходит извне — доезжает плавно; при drag идёт напрямую
    Behavior on live {
        enabled: !root.dragging
        NumberAnimation {
            duration: Theme.ms(120)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveFastSpatial
        }
    }

    Rectangle { // трек: тёмная утопленная поверхность
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        height: root._trackH
        radius: height / 2
        color: Theme.bgTrack
    }

    Rectangle { // заполненная часть акцентом, ведёт к центру ручки
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root._thumbX)
        height: root._trackH
        radius: height / 2
        color: Theme.accent
    }

    // гало — мягкий state-layer под ручкой (как в M3)
    Rectangle {
        id: halo
        anchors.centerIn: handle
        width: Theme.dp(38)
        height: width
        radius: width / 2
        color: Theme.alpha(Theme.accent, area.pressed ? 0.18 : 0.12)
        opacity: root.hot ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }
    }

    Rectangle { // ручка: крупный круг акцентом с контрастным кольцом
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: root._thumbX - width / 2
        width: root._thumbD
        height: root._thumbD
        radius: width / 2
        color: Theme.accent
        border.width: Theme.dp(2)
        border.color: Theme.bgOpaque
        scale: root.dragging ? 0.95 : (root.hovered ? 1.03 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        // широкая зона попадания по вертикали
        anchors.topMargin: -Theme.dp(6)
        anchors.bottomMargin: -Theme.dp(6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (mouse) => {
            root.dragging = true;
            const v = root.valueAt(mouse.x);
            root.live = v;
            root.moved(v);
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return;

            const v = root.valueAt(mouse.x);
            root.live = v;
            root.moved(v);
        }
        onReleased: {
            root.dragging = false;
            root.committed(root.live);
        }
    }
}
