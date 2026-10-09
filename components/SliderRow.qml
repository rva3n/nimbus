import QtQuick
import QtQuick.Layouts
import "../core"

RowLayout {
    id: sl
    property string icon: ""
    property real value: 0
    signal moved(real v)
    signal committed(real v)
    signal iconClicked()
    spacing: 10
    Text {
        font.family: Theme.font; font.pixelSize: 15; color: Theme.accent; text: sl.icon
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: sl.iconClicked() }
    }
    Item {
        Layout.fillWidth: true; implicitHeight: 24
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3; color: Theme.surfaceHi
            Rectangle { width: parent.width * Math.max(0, Math.min(1, sl.value)); height: parent.height; radius: 3; color: Theme.accent }
        }
        MouseArea {
            anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6
            onPositionChanged: (m) => sl.moved(Math.max(0, Math.min(1, m.x / track.width)))
            onPressed: (m) => sl.moved(Math.max(0, Math.min(1, m.x / track.width)))
            onReleased: sl.committed(sl.value)
        }
    }
    Text {
        Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
        font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext
        text: Math.round(Math.max(0, Math.min(1, sl.value)) * 100) + "%"
    }
}
