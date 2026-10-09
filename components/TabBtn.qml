import QtQuick
import "../core"

Rectangle {
    id: tabBtn
    property string label: ""
    property bool active: false
    signal clicked()
    implicitWidth: tbText.implicitWidth + 22
    implicitHeight: 30
    radius: 15
    color: tabBtn.active ? Theme.accent : Theme.surface
    Text {
        id: tbText
        anchors.centerIn: parent
        font.family: Theme.font; font.pixelSize: 12
        color: tabBtn.active ? Theme.bg : Theme.subtext
        text: tabBtn.label
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: tabBtn.clicked() }
}
