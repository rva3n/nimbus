import QtQuick
import QtQuick.Layouts
import "../core"

RowLayout {
    id: osdRow
    property string kind: "volume"
    property real value: 0
    property bool muted: false
    spacing: 10
    Text {
        font.family: Theme.font; font.pixelSize: 14; color: Theme.accent
        text: osdRow.kind === "volume" ? (osdRow.muted ? "\uf026" : "\uf028") : "\uf185"
    }
    Rectangle {
        Layout.preferredWidth: 150; Layout.preferredHeight: 8; radius: 4
        color: Theme.surfaceHi
        Rectangle {
            width: (osdRow.muted && osdRow.kind === "volume") ? 0 : parent.width * osdRow.value
            height: parent.height; radius: 4; color: Theme.accent
            Behavior on width { NumberAnimation { duration: 100 } }
        }
    }
    Text {
        font.family: Theme.font; font.pixelSize: 12; color: Theme.text
        text: (osdRow.muted && osdRow.kind === "volume") ? "mute" : Math.round(osdRow.value * 100) + "%"
    }
}
