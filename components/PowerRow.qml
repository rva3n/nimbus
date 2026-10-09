import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3 list item: иконка в круглом контейнере, подпись, шеврон справа.
// danger («Выключение») — error-тон иконки и контейнера.
Item {
    id: pr

    property string icon: ""
    property string label: ""
    property bool danger: false

    signal clicked()

    implicitHeight: Theme.dp(56)

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.bgTile

        Rectangle { // state layer (ховер/нажатие)
            anchors.fill: parent
            radius: bg.radius
            color: Theme.text
            opacity: prArea.pressed ? Theme.statePressed : (prArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Theme.easeStandard
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(8)
        anchors.rightMargin: Theme.dp(16)
        spacing: Theme.dp(12)

        Rectangle { // контейнер иконки
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusPill
            color: pr.danger ? Theme.errorContainer : Theme.bgTrack

            Icon {
                anchors.centerIn: parent
                name: pr.icon
                size: Theme.dp(20)
                color: pr.danger ? Theme.fgErrorContainer : Theme.subtext
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: pr.label
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyLarge")
            font.weight: Theme.typeWeight("bodyLarge")
        }

        Icon {
            Layout.alignment: Qt.AlignVCenter
            name: "chevron_right"
            size: Theme.dp(20)
            color: Theme.subtextDim
        }
    }

    MouseArea {
        id: prArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingCursor
        onClicked: pr.clicked()
    }
}
