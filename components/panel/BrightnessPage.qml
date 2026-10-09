import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
import ".."

// Яркость: крупное значение и слайдер в одной карточке.
ColumnLayout {
    id: brightnessPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "brightness"
    Layout.fillWidth: true; spacing: 10

    Card {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(6)
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("displayMedium")
            font.weight: Theme.typeWeight("displayMedium"); color: Theme.text
            text: Math.round(Sys.brightnessFraction * 100) + "%"
        }
        SliderRow {
            Layout.fillWidth: true
            icon: "brightness_6"
            value: Sys.brightnessFraction
            onMoved: (v) => { Sys.brightness = Math.round(v * Sys.brightnessMax); }
            onCommitted: (v) => { Sys.setBrightnessPct(v * 100); }
        }
    }
}
