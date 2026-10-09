import QtQuick
import "../core"

Rectangle {
    id: rb
    property string glyph: ""
    property bool active: false
    property bool danger: false
    signal clicked()
    implicitWidth: 30; implicitHeight: 30; radius: 15
    color: active ? Theme.accent : (rbMouse.containsMouse ? Theme.surfaceHi : "transparent")
    Behavior on color { ColorAnimation { duration: 100 } }
    Text {
        anchors.centerIn: parent
        font.family: Theme.font; font.pixelSize: 13
        color: rb.active ? Theme.bg : (rb.danger ? Theme.error : Theme.subtext)
        text: rb.glyph
    }
    MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: rb.clicked() }
}
