import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3 list item (строка внутри Card): прозрачная, hover — bgHover,
// нажатие — bgActive. Ведущая иконка 40×40 в контейнере; danger —
// error-тон контейнера и иконки («Выключение»).
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
        radius: Theme.radiusLg
        color: prArea.pressed ? Theme.bgActive : (prArea.containsMouse ? Theme.bgHover : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(8)
        anchors.rightMargin: Theme.dp(16)
        spacing: Theme.dp(12)

        Rectangle { // контейнер иконки
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusPill
            color: pr.danger ? Theme.errorContainer : Theme.bgTrack

            Icon {
                anchors.centerIn: parent
                name: pr.icon
                size: Theme.dp(20)
                color: pr.danger ? Theme.fgErrorContainer : Theme.subtext
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: pr.label
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyLarge")
            font.weight: Theme.typeWeight("bodyLarge")
        }

        Icon {
            Layout.alignment: Qt.AlignVCenter
            name: "chevron_right"
            size: Theme.dp(20)
            color: Theme.subtextDim
        }
    }

    MouseArea {
        id: prArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingCursor
        onClicked: pr.clicked()
    }
}
