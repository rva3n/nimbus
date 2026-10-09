import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property bool active: false
    signal tapped()
    Layout.fillWidth: true
    implicitHeight: 66
    radius: 16
    color: active ? Theme.a(Theme.accent, 0.22) : Theme.surface
    ColumnLayout {
        anchors.centerIn: parent; spacing: 4
        Text { Layout.alignment: Qt.AlignHCenter; font.family: Theme.font; font.pixelSize: 18; color: tile.active ? Theme.accent : Theme.subtext; text: tile.icon }
        Text { Layout.alignment: Qt.AlignHCenter; font.family: Theme.font; font.pixelSize: 10; color: tile.active ? Theme.text : Theme.subtext; text: tile.label }
    }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: tile.tapped() }
}
