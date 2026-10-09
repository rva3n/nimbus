import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."

ColumnLayout {
    id: brightnessPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "brightness"
    Layout.fillWidth: true; spacing: 12
    Text {
        Layout.alignment: Qt.AlignHCenter
        font.family: Theme.font; font.pixelSize: 40; font.bold: true; color: Theme.text
        text: Math.round(Sys.brightnessFraction * 100) + "%"
    }
    SliderRow {
        Layout.fillWidth: true
        icon: "\uf185"
        value: Sys.brightnessFraction
        onMoved: (v) => { Sys.brightness = Math.round(v * Sys.brightnessMax); }
        onCommitted: (v) => { Sys.setBrightnessPct(v * 100); }
    }
}
