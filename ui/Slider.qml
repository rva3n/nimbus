import QtQuick
import "../core"

// M3-слайдер: тонкий трек, круглая ручка. На ховере/перетаскивании ручка
// растёт, вокруг появляется гало-state layer. Высота 24, зона мыши выше трека.
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

    readonly property real _handleD: root.hot ? Theme.dp(18) : Theme.dp(16)
    // ручка не вылезает за края трека
    readonly property real _handleX: Math.max(root._handleD / 2, Math.min(root.width - root._handleD / 2, root.live * root.width))

    // значение приходит извне — доезжает плавно; при drag идёт напрямую
    Behavior on live {
        enabled: !root.dragging
        NumberAnimation {
            duration: Theme.ms(120)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveFastSpatial
        }
    }

    Rectangle { // трек
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        height: Theme.dp(6)
        radius: height / 2
        color: Theme.bgTrack
    }

    Rectangle { // заполненная часть, ведёт к центру ручки
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root._handleX)
        height: Theme.dp(6)
        radius: height / 2
        color: Theme.accent
    }

    // гало — state layer поверх трека, собранный через Theme.layer:
    // левая половина лежит на заливке, правая — на пустой части
    Item {
        id: halo
        anchors.centerIn: handle
        width: Theme.dp(32)
        height: width
        opacity: root.hot ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }

        Rectangle {
            anchors.left: parent.left
            width: parent.width / 2
            height: parent.height
            topLeftRadius: width
            bottomLeftRadius: width
            color: Theme.layer(Theme.accent, Theme.text, area.pressed ? Theme.statePressed : Theme.stateHover)
        }

        Rectangle {
            anchors.right: parent.right
            width: parent.width / 2
            height: parent.height
            topRightRadius: width
            bottomRightRadius: width
            color: Theme.layer(Theme.bgTrack, Theme.accent, area.pressed ? Theme.statePressed : Theme.stateHover)
        }
    }

    Rectangle { // ручка
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: root._handleX - width / 2
        width: root._handleD
        height: root._handleD
        radius: width / 2
        color: Theme.accent

        Behavior on width {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
        Behavior on height {
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
