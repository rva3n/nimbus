import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Тост уведомления: круглая иконка + «appName · summary» и body. Внешнюю
// капсулу рисует Island, поэтому отступы от её краёв задаём сами (4 по
// вертикали, 8 по горизонтали). API: current.
RowLayout {
    id: notifRow
    property var current: null
    spacing: Theme.dp(12)

    Rectangle { // круглый контейнер иконки
        Layout.alignment: Qt.AlignVCenter
        Layout.topMargin: Theme.dp(4)
        Layout.bottomMargin: Theme.dp(4)
        Layout.leftMargin: Theme.dp(8)
        implicitWidth: Theme.dp(28)
        implicitHeight: Theme.dp(28)
        radius: Theme.radiusPill
        color: Theme.accentContainer

        Icon {
            anchors.centerIn: parent
            name: "notifications"
            size: Theme.dp(15)
            color: Theme.fgAccentContainer
        }
    }

    ColumnLayout { // заголовок «appName · summary» и тело
        Layout.alignment: Qt.AlignVCenter
        Layout.topMargin: Theme.dp(4)
        Layout.bottomMargin: Theme.dp(4)
        Layout.rightMargin: Theme.dp(8)
        Layout.maximumWidth: Theme.dp(420)
        spacing: Theme.dp(2)

        Text {
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelLarge")
            font.weight: Theme.typeWeight("labelLarge")
            color: Theme.text
            text: notifRow.current ? ((notifRow.current.appName ? notifRow.current.appName + " · " : "") + (notifRow.current.summary || "")) : ""
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            visible: text !== ""
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
            color: Theme.subtext
            text: notifRow.current ? (notifRow.current.body || "") : ""
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
