import QtQuick
import "../core"

// M3-чип Oberon (порт lucidui/Chip.qml). Высота 30, радиус — скруглённый
// прямоугольник rad(8), не пилюля. Выбранный залит secondaryContainer, обычный —
// прозрачный корпус с бордером. kind: filter (галочка при выборе) | assist | input | suggestion.
Item {
    id: chip

    property string kind: "filter"
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

    readonly property bool showLead: (chip.kind === "filter" && chip.selected) || chip.icon !== ""
    readonly property color content: chip.selected ? Theme.fgSecondaryContainer : (chip.kind === "assist" ? Theme.text : Theme.subtext)

    implicitHeight: Theme.dp(30)
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
        radius: Theme.rad(8)
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

            radius: Theme.rad(8)
            tint: chip.content
            disabled: chip.disabled
            onClicked: chip.clicked()
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
            size: Theme.dp(17)
            color: chip.selected ? Theme.fgSecondaryContainer : Theme.primary
        }

        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "labelLarge"
            text: chip.label
            color: chip.content
        }

        Icon {
            visible: chip.closable
            anchors.verticalCenter: parent.verticalCenter
            name: "close"
            size: Theme.dp(16)
            color: chip.content

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.dp(4)
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.closeClicked()
            }

        }

    }

}
