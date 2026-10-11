import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Lucid-строка устройства (анатомия ui/ListItem): высота 56dp, ведущая иконка
// 40dp, заголовок + supporting, при выборе — secondaryContainer и залитая
// галочка. Положение в группе задаёт position (top|middle|bottom|single):
// внешние углы крупные, стыкующиеся — тугие (signature Lucid). Фон группы
// рисует владелец (ui/Card), строки прозрачны.
Rectangle {
    id: dr

    // корень прозрачный: фон рисует box (у Rectangle по умолчанию белый —
    // иначе невыбранные строки заливаются белым)
    color: "transparent"

    property string devName: ""
    property string icon: ""
    property string sub: ""
    property bool selected: false
    // top | middle | bottom | single — для групповых углов
    property string position: "single"
    // дополнительный контент справа (замок сети, сила сигнала и т.п.)
    property alias trailing: trailSlot.data
    // синоним заголовка (Lucid-имя)
    property alias headline: dr.devName

    signal clicked()

    readonly property bool _first: dr.position === "" || dr.position === "top" || dr.position === "single"
    readonly property bool _last: dr.position === "" || dr.position === "bottom" || dr.position === "single"
    readonly property real outerRadius: Theme.rad(20)
    readonly property real innerRadius: Theme.rad(5)

    implicitHeight: Theme.dp(56)

    Rectangle {
        id: box

        anchors.fill: parent
        color: dr.selected ? Theme.secondaryContainer : "transparent"
        topLeftRadius: dr._first ? dr.outerRadius : dr.innerRadius
        topRightRadius: dr._first ? dr.outerRadius : dr.innerRadius
        bottomLeftRadius: dr._last ? dr.outerRadius : dr.innerRadius
        bottomRightRadius: dr._last ? dr.outerRadius : dr.innerRadius

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
    }

    StateLayer {
        anchors.fill: parent
        radius: dr.innerRadius
        tint: dr.selected ? Theme.fgSecondaryContainer : Theme.text
        onClicked: dr.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(14)
        anchors.rightMargin: Theme.dp(16)
        spacing: Theme.dp(12)

        Rectangle { // ведущая иконка 40×40
            visible: dr.icon !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.rad(12)
            color: dr.selected ? Theme.alpha(Theme.fgSecondaryContainer, 0.10) : Theme.bgTrack

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }

            Icon {
                anchors.centerIn: parent
                name: dr.icon
                size: Theme.dp(22)
                fill: dr.selected ? 1 : 0
                color: dr.selected ? Theme.fgSecondaryContainer : Theme.subtext

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.dp(1)

            LText {
                Layout.fillWidth: true
                role: "bodyLarge"
                weight: 480
                color: dr.selected ? Theme.fgSecondaryContainer : Theme.text
                elide: Text.ElideRight
                text: dr.devName
            }

            LText {
                Layout.fillWidth: true
                visible: dr.sub !== ""
                role: "bodySmall"
                color: dr.selected ? Theme.alpha(Theme.fgSecondaryContainer, 0.8) : Theme.subtext
                elide: Text.ElideRight
                text: dr.sub
            }
        }

        Row {
            id: trailSlot

            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.dp(8)
        }

        Icon { // галочка выбора
            Layout.alignment: Qt.AlignVCenter
            visible: dr.selected
            name: "check"
            size: Theme.dp(20)
            fill: 1
            color: Theme.fgSecondaryContainer
        }
    }
}
