import QtQuick
import "../core"

// Слайдер в стиле yoru: толстый скруглённый (не пилюля) трек, заливка
// акцентом, тонкая вертикальная ручка-риска на границе заливки и опциональная
// иконка внутри заливки слева (как volume/brightness в control center).
// Крупной круглой ручки и кольца нет.
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
    // иконка внутри заливки (volume_up, brightness_6, ...); "" — без иконки
    property string icon: ""

    readonly property bool hovered: area.containsMouse
    readonly property bool hot: root.enabled && (root.hovered || root.dragging)

    signal moved(real v)
    signal committed(real v)
    // клик по иконке внутри заливки (mute/переключение у вызывающего кода)
    signal iconClicked()

    implicitWidth: Theme.dp(200)
    // трек + небольшой запас под ховер-утолщение ручки
    implicitHeight: Theme.dp(32)
    opacity: root.enabled ? 1 : Theme.disabledContent

    Component.onCompleted: root.live = root.value
    onValueChanged: {
        if (!root.dragging)
            root.live = root.value;
    }

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    // v = x / ширине трека
    function valueAt(px) { return root.clamp01(px / Math.max(1, root.width)) }

    // геометрия: толстый rounded-rect трек, тонкая ручка-риска, иконка в заливке
    readonly property real _trackH: Theme.dp(28)
    readonly property real _radius: Theme.dp(12)
    readonly property real _handleW: Theme.dp(3)
    readonly property real _handleH: root._trackH - Theme.dp(10)
    readonly property real _iconMargin: Theme.dp(10)
    readonly property real _iconSize: Theme.dp(16)
    // ширина заливки: по live — при drag напрямую, извне value доезжает плавно
    readonly property real _fillW: Math.max(0, Math.min(root.width, root.live * root.width))
    // иконка видна, только если заливка достаточно широка, чтобы её вместить
    readonly property bool _iconShown: root.icon !== ""
        && root._fillW > root._iconMargin + root._iconSize + Theme.dp(6)

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
        radius: root._radius
        color: Theme.bgTrack
    }

    Rectangle { // заливка акцентом, тянется до границы ручки
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        width: root._fillW
        height: root._trackH
        radius: root._radius
        color: Theme.accent
        clip: true

        Icon { // иконка внутри заливки слева (тёмный «ink» на акценте)
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            x: root._iconMargin
            visible: root._iconShown
            name: root.icon
            size: root._iconSize
            color: Theme.fgAccent
        }
    }

    Rectangle { // ручка: тонкая вертикальная риска на границе заливки
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: root._fillW - width / 2
        width: root._handleW
        height: root.hot ? root._handleH + Theme.dp(4) : root._handleH
        radius: Theme.dp(2)
        color: Theme.text

        Behavior on height {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
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

    // клик по иконке (mute и т.п.) — объявлен поверх area, перехватывает только
    // область иконки, поэтому не мешает перетаскиванию заливки. Позиция
    // повторяет iconItem (fill.x == 0), т.к. anchor к вложенному элементу нельзя.
    MouseArea {
        id: iconArea
        x: root._iconMargin - Theme.dp(4)
        width: root._iconSize + Theme.dp(8)
        height: root._iconSize + Theme.dp(8)
        anchors.verticalCenter: parent.verticalCenter
        visible: root._iconShown
        cursorShape: Qt.PointingHandCursor
        onClicked: root.iconClicked()
    }
}
