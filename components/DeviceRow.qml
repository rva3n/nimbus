import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3 list item устройства: ведущая иконка 40×40, имя; при выборе — accentContainer
// и галочка. Строка прозрачная, ховер — bgHover (внутри ui/Card).
Rectangle {
    id: dr
    property string devName: ""
    property string icon: ""
    property bool selected: false
    signal clicked()
    implicitHeight: Theme.dp(56)
    radius: Theme.radiusMd
    color: dr.selected ? Theme.accentContainer : (mouse.containsMouse ? Theme.bgHover : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(8)
        anchors.rightMargin: Theme.dp(8)
        spacing: Theme.dp(8)

        Rectangle { // ведущая иконка устройства
            visible: dr.icon !== ""
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusMd
            color: dr.selected ? Theme.accentContainer : Theme.bgTrack

            Icon {
                anchors.centerIn: parent
                name: dr.icon
                size: Theme.dp(20)
                color: dr.selected ? Theme.fgAccentContainer : Theme.subtext
            }
        }

        Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
            font.weight: Theme.typeWeight("bodyLarge")
            color: dr.selected ? Theme.fgAccentContainer : Theme.text
            text: dr.devName
        }

        Icon {
            visible: dr.selected
            name: "check"
            size: Theme.dp(18)
            color: dr.selected ? Theme.fgAccentContainer : Theme.accent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dr.clicked()
    }
}
