import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Lucid-строка сессии (питание): высота 56dp, ведущая иконка 40dp,
// заголовок bodyLarge и шеврон справа. danger-вариант залит errorContainer,
// текст/иконки — error-тоном («Выключение»). Строка живёт внутри ui/Card;
// ховер и нажатие рисует StateLayer.
Item {
    id: pr

    property string icon: ""
    property string label: ""
    property bool danger: false

    signal clicked()

    implicitHeight: Theme.dp(56)

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.rad(16)
        color: pr.danger ? Theme.errorContainer : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
    }

    StateLayer {
        radius: bg.radius
        tint: pr.danger ? Theme.error : Theme.text
        onClicked: pr.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(8)
        anchors.rightMargin: Theme.dp(16)
        spacing: Theme.dp(12)

        Rectangle { // контейнер иконки 40×40
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusPill
            color: pr.danger ? Theme.alpha(Theme.fgErrorContainer, 0.12) : Theme.bgTrack

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }

            Icon {
                anchors.centerIn: parent
                name: pr.icon
                size: Theme.dp(22)
                color: pr.danger ? Theme.fgErrorContainer : Theme.subtext
            }
        }

        LText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            role: "bodyLarge"
            color: pr.danger ? Theme.fgErrorContainer : Theme.text
            elide: Text.ElideRight
            text: pr.label
        }

        Icon {
            Layout.alignment: Qt.AlignVCenter
            name: "chevron_right"
            size: Theme.dp(20)
            color: pr.danger ? Theme.fgErrorContainer : Theme.subtextDim
        }
    }
}
