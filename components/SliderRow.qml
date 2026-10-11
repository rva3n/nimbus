import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Строка управления в стиле yoru: слайдер с иконкой ВНУТРИ заливки,
// проценты справа. Клик по иконке — iconClicked (mute/переключение).
// Фон прозрачный, ховер — bgHover (внутри ui/Card).
Rectangle {
    id: sl
    property string icon: ""
    property real value: 0
    signal moved(real v)
    signal committed(real v)
    signal iconClicked()
    implicitHeight: Theme.dp(56)
    radius: Theme.radiusMd
    color: slHover.containsMouse ? Theme.bgHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }

    // только ховер, чтобы не перехватывать слайдер
    MouseArea {
        id: slHover
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(8)
        anchors.rightMargin: Theme.dp(8)
        spacing: Theme.dp(8)

        Slider {
            Layout.fillWidth: true
            icon: sl.icon
            value: sl.value
            onMoved: (v) => sl.moved(v)
            onCommitted: (v) => sl.committed(v)
            onIconClicked: sl.iconClicked()
        }

        Text {
            Layout.preferredWidth: Theme.dp(40)
            horizontalAlignment: Text.AlignRight
            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
            text: Math.round(Math.max(0, Math.min(1, sl.value)) * 100) + "%"
        }
    }
}
