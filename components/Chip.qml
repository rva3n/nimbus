import QtQuick
import "../core"

Rectangle {
    id: chip
    property string label: ""
    property bool active: false
    signal clicked()
    implicitWidth: chipText.implicitWidth + 18
    implicitHeight: 26
    radius: 13
    color: chip.active ? Theme.a(Theme.accent, 0.25) : Theme.surface
    Text {
        id: chipText
        anchors.centerIn: parent
        font.family: Theme.font; font.pixelSize: 11
        color: chip.active ? Theme.accent : Theme.subtext
        text: chip.label
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
}
