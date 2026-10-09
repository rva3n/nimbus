import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Тост уведомления: иконка + «appName · summary» и body (обе строки с elide).
RowLayout {
    id: notifRow
    property var current: null
    spacing: Theme.dp(10)

    Icon {
        Layout.alignment: Qt.AlignVCenter
        name: "notifications"
        size: Theme.dp(18)
        color: Theme.accent
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: Theme.dp(300)
        spacing: 0

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
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
            color: Theme.subtext
            text: notifRow.current ? (notifRow.current.body || "") : ""
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
