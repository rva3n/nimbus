import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Строка громкости/яркости: ui/Slider на всю ширину, справа процент —
// LText labelLarge с табличными цифрами. Фон прозрачный, ховер — bgHover
// (строка живёт внутри ui/Card). Клик по ведущей иконке — iconClicked.
Rectangle {
    id: sl

    property string icon: ""
    property real value: 0

    signal moved(real v)
    signal committed(real v)
    signal iconClicked()

    implicitHeight: Theme.dp(56)
    radius: Theme.rad(16)
    color: slHover.containsMouse ? Theme.bgHover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.durDefaultEffects
        }
    }

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

        LText {
            Layout.preferredWidth: Theme.dp(44)
            horizontalAlignment: Text.AlignRight
            role: "labelLarge"
            tabular: true
            color: Theme.subtext
            text: Math.round(Math.max(0, Math.min(1, sl.value)) * 100) + "%"
        }
    }
}
