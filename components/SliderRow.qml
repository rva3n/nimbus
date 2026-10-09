import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Строка управления: ведущая иконка 40×40 (клик — iconClicked), M3-слайдер,
// проценты справа. Фон прозрачный, ховер — bgHover (внутри ui/Card).
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

        Rectangle { // ведущая иконка; клик — mute/переключение
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusMd
            color: Theme.bgTrack

            Icon {
                anchors.centerIn: parent
                name: sl.icon
                size: Theme.dp(20)
                color: Theme.subtext
            }

            MouseArea {
                anchors.fill: parent
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
}
