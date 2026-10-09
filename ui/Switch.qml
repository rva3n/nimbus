import QtQuick
import "../core"

// M3-переключатель 52x32: трек-pill, ручка растёт при включении, x/размер/цвет
// анимируются. Клик сам меняет checked и эмитит toggled().
Item {
    id: root

    property bool checked: false
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed

    signal toggled()

    implicitWidth: Theme.dp(52)
    implicitHeight: Theme.dp(32)
    opacity: root.enabled ? 1 : Theme.disabledContent

    Rectangle { // трек
        anchors.fill: parent
        radius: Theme.pill(height)
        color: root.checked ? Theme.accent : Theme.bgTrack
        border.width: root.checked ? 0 : Theme.dp(2)
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.ms(180)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
    }

    Rectangle { // state layer вокруг ручки
        id: halo
        anchors.centerIn: thumb
        width: Theme.dp(40)
        height: width
        radius: width / 2
        color: root.checked ? Theme.accent : Theme.text
        opacity: (root.hovered || root.pressed) ? (root.pressed ? Theme.statePressed : Theme.stateHover) : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(120)
            }
        }
    }

    Rectangle { // ручка
        id: thumb
        anchors.verticalCenter: parent.verticalCenter
        width: root.checked ? Theme.dp(24) : Theme.dp(16)
        height: width
        x: root.checked ? Theme.dp(20) : Theme.dp(8)
        radius: width / 2
        color: root.checked ? Theme.fgOnFill : Theme.outlineStrong

        Behavior on x {
            NumberAnimation {
                duration: Theme.ms(180)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Theme.ms(180)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Theme.ms(180)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(180)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -Theme.dp(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // клик сам переключает checked; toggled() — для внешней реакции
        onClicked: {
            root.checked = !root.checked;
            root.toggled();
        }
    }
}
