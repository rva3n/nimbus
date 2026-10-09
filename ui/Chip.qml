import QtQuick
import "../core"

// M3-чип: пилюля высотой 30. Обычный — прозрачный корпус с бордером; выбранный —
// accentContainer, а галочка занимает место ведущей иконки.
Item {
    id: root

    property string label: ""
    // необязательная ведущая иконка
    property string icon: ""
    property bool selected: false
    // синоним selected
    property alias active: root.selected
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    readonly property bool hot: root.enabled && (root.hovered || root.pressed)

    signal clicked()

    readonly property string _lead: root.selected ? "check" : root.icon
    readonly property bool _hasLead: root._lead !== ""
    readonly property color _content: root.selected ? Theme.fgAccentContainer : Theme.subtext

    implicitHeight: Theme.dp(30)
    implicitWidth: row.implicitWidth + Theme.dp(24)
    opacity: root.enabled ? 1 : Theme.disabledContent

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.ms(180)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }
    }

    Rectangle { // корпус
        id: bg
        anchors.fill: parent
        radius: Theme.pill(height)
        color: root.selected ? Theme.accentContainer : "transparent"
        border.width: root.selected ? 0 : 1
        border.color: Theme.divider

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }

        Rectangle { // hover/нажатие — state layer
            anchors.fill: parent
            radius: parent.radius
            color: root.selected ? Theme.fgAccentContainer : Theme.text
            opacity: root.hot ? (root.pressed ? Theme.statePressed : Theme.stateHover) : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(120)
                }
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.dp(6)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root._hasLead
            name: root._lead
            size: Theme.dp(16)
            color: root._content

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(120)
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root._content
            font.family: Theme.textFont
            font.pixelSize: Theme.fs(11)
            font.weight: Theme.typeWeight("labelMedium")

            Behavior on color {
                ColorAnimation {
                    duration: Theme.ms(120)
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -Theme.dp(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
