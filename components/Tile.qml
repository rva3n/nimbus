import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3-плитка быстрых настроек: иконка сверху, подпись снизу.
// active — accentContainer, обычная — bgTile; ховер — bgHover, нажатие — bgActive.
Item {
    id: tile

    property string icon: ""
    property string label: ""
    property bool active: false

    signal tapped()

    Layout.fillWidth: true
    implicitHeight: Theme.dp(72)
    scale: area.pressed ? 0.97 : 1

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
        radius: Theme.radiusLg
        color: tile.active ? Theme.accentContainer
             : (area.pressed ? Theme.bgActive : (area.containsMouse ? Theme.bgHover : Theme.bgTile))
        border.width: 1
        border.color: Theme.a(Theme.outline, 0.25)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.dp(4)

        Icon {
            Layout.alignment: Qt.AlignHCenter
            name: tile.icon
            size: Theme.dp(24)
            color: tile.active ? Theme.fgAccentContainer : Theme.subtext

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: tile.label
            color: tile.active ? Theme.fgAccentContainer : Theme.text
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelMedium")
            font.weight: Theme.typeWeight("labelMedium")

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingCursor
        onClicked: tile.tapped()
    }
}
