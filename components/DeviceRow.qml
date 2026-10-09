import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3 list item устройства: имя, при выборе — accentContainer и галочка.
Rectangle {
    id: dr
    property string devName: ""
    property bool selected: false
    signal clicked()
    implicitHeight: Theme.dp(48)
    radius: Theme.radiusMd
    color: dr.selected ? Theme.accentContainer : (mouse.containsMouse ? Theme.bgHover : Theme.bgTile)
    Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(16)
        anchors.rightMargin: Theme.dp(16)
        spacing: Theme.dp(8)
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
            color: Theme.accent
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
