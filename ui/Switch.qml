import QtQuick
import "../core"

// M3-переключатель Oberon (порт lucidui/Switch.qml): трек 48×28 pill,
// ручка растёт при включении и ещё раз под нажатием, несёт глиф check/close.
// Клик сообщает предполагаемое новое значение; checked принадлежит вызывающему коду.
Item {
    id: root

    activeFocusOnTab: !root.disabled

    property bool checked: false
    property bool disabled: false
    property bool icons: true
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed

    signal toggled(bool value)

    function activate() {
        if (root.disabled) return;
        root.toggled(!root.checked);
    }

    Keys.onPressed: (event) => {
        if (root.disabled || event.isAutoRepeat) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate();
            event.accepted = true;
        }
    }

    implicitWidth: Theme.dp(48)
    implicitHeight: Theme.dp(28)
    opacity: root.disabled ? Theme.disabledContent : 1

    Rectangle { // трек
        id: track

        anchors.fill: parent
        radius: Theme.pill(height)
        color: root.checked ? Theme.primary : Theme.bgSunken
        border.width: root.checked ? 0 : Theme.dp(2)
        border.color: Theme.outlineStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    Rectangle { // ручка
        id: thumb

        property real d: area.pressed && !root.disabled ? Theme.dp(26) : (root.checked || root.icons ? Theme.dp(22) : Theme.dp(14))
        // ход смягчается сам по себе; если бы x следовал той же кривой, что и
        // размер, анимация перезапускалась бы каждый кадр и стояла на месте,
        // пока размер не успокоится
        property real pos: root.checked ? 1 : 0

        width: thumb.d
        height: thumb.d
        radius: thumb.d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.dp(3) + (Theme.dp(22) - thumb.d) / 2 + thumb.pos * (root.width - Theme.dp(28))
        color: root.checked ? Theme.fgPrimary : Theme.outlineStrong

        Behavior on pos {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Behavior on d {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        Rectangle { // state ring 38dp
            anchors.centerIn: parent
            width: Theme.dp(38)
            height: Theme.dp(38)
            radius: Theme.dp(19)
            color: root.checked ? Theme.primary : Theme.text
            opacity: root.disabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))
        }

        Icon {
            anchors.centerIn: parent
            visible: root.icons
            name: root.checked ? "check" : "close"
            size: Theme.dp(15)
            weight: 600
            color: root.checked ? Theme.fgPrimaryContainer : Theme.bgHover
            opacity: root.checked ? 1 : 0.9
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -Theme.dp(4)
        hoverEnabled: true
        enabled: !root.disabled
        cursorShape: Qt.PointingHandCursor
        // checked принадлежит владельцу; toggled сообщает следующее значение
        onClicked: root.activate()
    }

    Rectangle {
        anchors.fill: track
        z: 10
        visible: root.activeFocus
        radius: track.radius
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRingColor
    }

}
