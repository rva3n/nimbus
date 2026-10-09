import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Строка управления: иконка (клик — iconClicked), M3-слайдер, процент справа.
RowLayout {
    id: sl
    property string icon: ""
    property real value: 0
    signal moved(real v)
    signal committed(real v)
    signal iconClicked()
    spacing: Theme.dp(10)

    Icon {
        name: sl.icon
        size: Theme.dp(22)
        color: Theme.accent
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.dp(6)
            cursorShape: Qt.PointingHandCursor
            onClicked: sl.iconClicked()
        }
    }

    Slider {
        Layout.fillWidth: true
        value: sl.value
        onMoved: (v) => sl.moved(v)
        onCommitted: (v) => sl.committed(v)
    }

    Text {
        Layout.preferredWidth: Theme.dp(40)
        horizontalAlignment: Text.AlignRight
        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
        font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
        text: Math.round(Math.max(0, Math.min(1, sl.value)) * 100) + "%"
    }
}
