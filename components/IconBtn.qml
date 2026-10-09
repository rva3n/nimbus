import QtQuick
import "../core"

Text {
    id: btn
    property bool btnEnabled: true
    property string glyph: ""
    signal clicked()
    text: glyph
    font.family: Theme.font
    font.pixelSize: 14
    color: btnEnabled ? (btnMouse.containsMouse ? Theme.accent : Theme.subtext) : Theme.a(Theme.subtext, 0.35)
    Behavior on color { ColorAnimation { duration: 100 } }
    MouseArea {
        id: btnMouse
        anchors.fill: parent; anchors.margins: -6
        hoverEnabled: true; enabled: parent.btnEnabled
        onClicked: parent.clicked()
    }
}
