import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: tr
    property string label: ""
    property string sub: ""
    property bool active: false
    signal toggled()
    implicitHeight: 52
    radius: 14
    color: Theme.surface
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 10
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text { font.family: Theme.font; font.pixelSize: 14; color: Theme.text; text: tr.label }
            Text { font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext; text: tr.sub }
        }
        Rectangle {
            implicitWidth: 44; implicitHeight: 26; radius: 13
            color: tr.active ? Theme.accent : Theme.surfaceHi
            Rectangle {
                width: 20; height: 20; radius: 10; color: Theme.bg
                y: 3; x: tr.active ? 21 : 3
                Behavior on x { NumberAnimation { duration: 140 } }
            }
            MouseArea { anchors.fill: parent; onClicked: tr.toggled() }
        }
    }
}
