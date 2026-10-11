import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// OSD-строка: контейнер иконки источника + трек значения + процент/«mute».
RowLayout {
    id: osdRow
    property string kind: "volume"
    property real value: 0
    property bool muted: false
    spacing: Theme.dp(10)

    Rectangle { // контейнер иконки источника
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: Theme.dp(26)
        implicitHeight: Theme.dp(26)
        radius: Theme.radiusPill
        color: Theme.accentContainer

        Icon {
            anchors.centerIn: parent
            name: osdRow.kind === "volume" ? (osdRow.muted ? "volume_off" : "volume_up") : "brightness_6"
            size: Theme.dp(16)
            color: Theme.fgAccentContainer
        }
    }

    Rectangle { // трек
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Theme.dp(140)
        Layout.preferredHeight: Theme.dp(12)
        radius: Theme.radiusPill
        color: Theme.bgTrack

        Rectangle { // заливка значения
            id: osdFill
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

        Rectangle { // бегунок (как у ui/Slider)
            width: Theme.dp(18)
            height: Theme.dp(18)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, osdFill.width - width / 2))
            color: Theme.accent
            border.width: Theme.dp(2)
            border.color: Theme.bgOpaque
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
