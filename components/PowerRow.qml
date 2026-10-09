import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: pr
    property string icon: ""
    property string label: ""
    signal clicked()
    implicitHeight: 46
    radius: 12
    color: prMouse.containsMouse ? Theme.a(Theme.accent, 0.16) : Theme.surface
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
        Text { font.family: Theme.font; font.pixelSize: 15; color: Theme.accent; text: pr.icon }
        Text { font.family: Theme.font; font.pixelSize: 14; color: Theme.text; text: pr.label; Layout.fillWidth: true }
    }
    MouseArea { id: prMouse; anchors.fill: parent; hoverEnabled: true; onClicked: pr.clicked() }
}
