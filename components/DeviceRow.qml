import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: dr
    property string devName: ""
    property bool selected: false
    signal clicked()
    implicitHeight: 40
    radius: 10
    color: selected ? Theme.a(Theme.accent, 0.18) : Theme.surface
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
        Text { font.family: Theme.font; font.pixelSize: 13; color: dr.selected ? Theme.accent : Theme.text; text: dr.devName; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { visible: dr.selected; font.family: Theme.font; font.pixelSize: 12; color: Theme.accent; text: "\uf00c" }
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: dr.clicked() }
}
