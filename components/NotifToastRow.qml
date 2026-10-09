import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Тост уведомления: контейнер иконки + «appName · summary» и body (обе строки с elide).
RowLayout {
    id: notifRow
    property var current: null
    spacing: Theme.dp(10)

    Rectangle { // контейнер иконки
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: Theme.dp(28)
        implicitHeight: Theme.dp(28)
        radius: Theme.radiusPill
        color: Theme.accentContainer

        Icon {
            anchors.centerIn: parent
            name: "notifications"
            size: Theme.dp(16)
            color: Theme.fgAccentContainer
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: Theme.dp(300)
        spacing: 1

        Text {
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("titleSmall")
            font.weight: Theme.typeWeight("titleSmall")
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
