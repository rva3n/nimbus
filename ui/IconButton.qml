import QtQuick
import "../core"

// Круглая M3-кнопка-иконка Nimbus.
// variant: standard | filled | tonal; size: s=32 | m=40.
Item {
    id: ib

    property string icon: ""
    property string size: "s"
    property string variant: "standard"
    property bool disabled: false

    signal clicked()

    readonly property int _dim: ib.size === "m" ? Theme.dp(40) : Theme.dp(32)
    readonly property int _iconPx: Math.round(ib._dim * 0.55)

    readonly property color _container: {
        if (ib.disabled)
            return ib.variant === "standard" ? "transparent" : Theme.a(Theme.text, Theme.disabledContainer);
        if (ib.variant === "filled")
            return Theme.accent;
        if (ib.variant === "tonal")
            return Theme.accentContainer;
        return "transparent";
    }

    readonly property color _content: {
        if (ib.disabled)
            return ib.variant === "standard" ? Theme.subtextDim : Theme.a(Theme.text, Theme.disabledContent);
        if (ib.variant === "filled")
            return Theme.fgOnFill;
        if (ib.variant === "tonal")
            return Theme.fgAccentContainer;
        return Theme.subtext;
    }

    implicitWidth: ib._dim
    implicitHeight: ib._dim

    Rectangle {
        id: box

        anchors.fill: parent
        radius: Theme.radiusPill
        color: ib._container

        // state layer: standard — тонкий слой, filled/tonal — поверх заливки
        Rectangle {
            anchors.fill: parent
            radius: box.radius
            color: ib._content
            opacity: ib.disabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Theme.easeStandard
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    Icon {
        anchors.centerIn: parent
        name: ib.icon
        size: ib._iconPx
        color: ib._content
        scale: (area.pressed && !ib.disabled) ? 0.92 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: !ib.disabled
        cursorShape: Qt.PointingCursor
        onClicked: ib.clicked()
    }

}
