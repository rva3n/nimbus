import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// OSD-строка в стиле yoru: толстый трек с акцентной заливкой, иконка внутри
// заливки слева, тонкий вертикальный ползунок на границе; процент справа.
RowLayout {
    id: osdRow
    property string kind: "volume"
    property real value: 0
    property bool muted: false
    spacing: Theme.dp(10)

    Rectangle { // трек
        id: osdTrack
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Theme.dp(160)
        Layout.preferredHeight: Theme.dp(28)
        radius: Theme.dp(12)
        color: Theme.bgTrack
        // без clip: ручка должна выступать за трек сверху и снизу (как в yoru)

        Rectangle { // заливка значения
            id: osdFill
            width: (osdRow.muted && osdRow.kind === "volume") ? 0 : osdTrack.width * osdRow.value
            height: parent.height
            radius: osdTrack.radius
            color: Theme.accent
            // иконку клипуем по заливке (раньше это делал клип трека)
            clip: true
            Behavior on width {
                NumberAnimation {
                    duration: Theme.durDefaultEffects
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Icon { // иконка внутри заливки (как у yoru)
                x: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(16)
                height: Theme.dp(16)
                visible: osdFill.width > Theme.dp(32)
                name: osdRow.kind === "volume" ? (osdRow.muted ? "volume_off" : "volume_up") : "brightness_6"
                size: Theme.dp(16)
                color: Theme.fgAccent
            }
        }

        Rectangle { // тонкий вертикальный ползунок: выше трека, торчит сверху и снизу
            width: Theme.dp(3)
            height: osdTrack.height + Theme.dp(8)
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(osdTrack.width - width, osdFill.width - width / 2))
            color: Theme.text
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
