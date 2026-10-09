import QtQuick
import "../core"

// Специализированный M3-чип таба (стиль ui/Chip): пилюля, выбранный —
// accentContainer, иначе прозрачный корпус с бордером.
Item {
    id: tabBtn

    property string label: ""
    property bool active: false

    signal clicked()

    implicitWidth: tbText.implicitWidth + Theme.dp(24)
    implicitHeight: Theme.dp(30)
    scale: tbArea.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durQuick
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEffects
        }
    }

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.pill(height)
        color: tabBtn.active ? Theme.accentContainer : "transparent"
        border.width: tabBtn.active ? 0 : 1
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
            color: tabBtn.active ? Theme.fgAccentContainer : Theme.text
            opacity: tbArea.pressed ? Theme.statePressed : (tbArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(120)
                }
            }
        }
    }

    Text {
        id: tbText

        anchors.centerIn: parent
        text: tabBtn.label
        color: tabBtn.active ? Theme.fgAccentContainer : Theme.subtext
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelMedium")
        font.weight: Theme.typeWeight("labelMedium")

        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(120)
            }
        }
    }

    MouseArea {
        id: tbArea

        anchors.fill: parent
        anchors.margins: -Theme.dp(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tabBtn.clicked()
    }
}
