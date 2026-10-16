import QtQuick
import "../core"

// M3-чип Oberon (порт lucidui/Chip.qml). Высота 30, радиус — скруглённый
// прямоугольник rad(8), не пилюля. Выбранный залит secondaryContainer, обычный —
// прозрачный корпус с бордером. kind: filter (галочка при выборе) | assist | input | suggestion.
Item {
    id: chip

    activeFocusOnTab: !chip.disabled

    property string kind: "filter"
    property string size: "md"
    property string label: ""
    // синоним label (Lucid-имя)
    property alias text: chip.label
    property string icon: ""
    property bool selected: false
    property bool closable: false
    property bool disabled: false
    // синоним selected
    property alias active: chip.selected
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    readonly property bool hot: chip.enabled && (chip.hovered || chip.pressed)

    signal clicked()
    signal closeClicked()

    function activate() {
        if (chip.disabled) return;
        chip.clicked();
    }

    Keys.onPressed: (event) => {
        if (chip.disabled || event.isAutoRepeat) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            chip.activate();
            event.accepted = true;
        }
    }

    readonly property bool showLead: (chip.kind === "filter" && chip.selected) || chip.icon !== ""
    readonly property color content: chip.selected ? Theme.fgSecondaryContainer
        : (chip.kind === "assist" || chip.kind === "suggestion" ? Theme.text : Theme.subtext)

    implicitHeight: chip.size === "sm" ? Theme.dp(26) : Theme.dp(30)
    implicitWidth: row.implicitWidth + (chip.showLead ? Theme.dp(10) : Theme.dp(14)) + (chip.closable ? Theme.dp(8) : Theme.dp(14))
    opacity: chip.disabled ? Theme.disabledContent : 1

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durFastSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: chip.size === "sm" ? Theme.radiusPill : Theme.rad(8)
        color: chip.selected ? Theme.secondaryContainer : "transparent"
        border.width: chip.selected ? 0 : 1
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        StateLayer {
            id: area

            radius: bg.radius
            tint: chip.content
            disabled: chip.disabled
            onClicked: chip.activate()
        }

    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        x: chip.showLead ? Theme.dp(8) : Theme.dp(14)
        spacing: Theme.dp(6)

        Icon {
            visible: chip.showLead
            anchors.verticalCenter: parent.verticalCenter
            name: (chip.kind === "filter" && chip.selected) ? "check" : chip.icon
            size: Theme.dp(chip.size === "sm" ? 14 : 17)
            color: chip.selected ? Theme.fgSecondaryContainer : Theme.primary
        }

        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: chip.size === "sm" ? "labelMedium" : "labelLarge"
            text: chip.label
            color: chip.content
        }

        Icon {
            visible: chip.closable
            anchors.verticalCenter: parent.verticalCenter
            name: "close"
            size: Theme.dp(chip.size === "sm" ? 14 : 16)
            color: chip.content

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.dp(4)
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.closeClicked()
            }

        }

    }

    Rectangle {
        anchors.fill: parent
        z: 10
        visible: chip.activeFocus
        radius: bg.radius
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRingColor
    }

}
