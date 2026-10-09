import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// OSD-строка: иконка источника + трек значения + процент/«mute».
RowLayout {
    id: osdRow
    property string kind: "volume"
    property real value: 0
    property bool muted: false
    spacing: Theme.dp(10)

    Icon {
        Layout.alignment: Qt.AlignVCenter
        name: osdRow.kind === "volume" ? (osdRow.muted ? "volume_off" : "volume_up") : "brightness_6"
        size: Theme.dp(18)
        color: Theme.accent
    }

    Rectangle { // трек
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Theme.dp(140)
        Layout.preferredHeight: Theme.dp(8)
        radius: Theme.radiusPill
        color: Theme.bgTrack

        Rectangle { // заливка значения
            width: (osdRow.muted && osdRow.kind === "volume") ? 0 : parent.width * osdRow.value
            height: parent.height
            radius: Theme.radiusPill
            color: Theme.accent
            Behavior on width {
                NumberAnimation {
                    duration: Theme.durDefaultEffects
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelSmall")
        font.weight: Theme.typeWeight("labelSmall")
        color: Theme.text
        text: (osdRow.muted && osdRow.kind === "volume") ? "mute" : Math.round(osdRow.value * 100) + "%"
    }
}
