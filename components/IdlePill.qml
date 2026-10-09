import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Пилюля idle/OSD/уведомлений: строки compactRow + osdRow + notifRow.
// Строки монтируются в Island; наружу отдаются implicitWidth/implicitHeight.
Item {
    id: holder
    property string mode: "idle"
    property date now: new Date()
    property string output: ""
    property var shell: null
    implicitWidth: mode === "notif" ? notifRow.implicitWidth
                 : mode === "osd" ? osdRow.implicitWidth
                 : compactRow.implicitWidth
    implicitHeight: Theme.dp(30)

    // idle: воркспейсы + погода + время + колокольчик панели
    RowLayout {
        id: compactRow
        visible: holder.mode === "idle"
        anchors.centerIn: parent
        spacing: Theme.dp(10)

        WorkspacesRow {
            Layout.alignment: Qt.AlignVCenter
            output: holder.output
        }

        RowLayout { // погодный чип: иконка + температура, без места
            visible: Weather.hasData
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.dp(4)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: Weather.icon
                size: Theme.dp(14)
                color: Theme.subtext
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
                color: Theme.subtext
                text: Math.round(Weather.temp) + "°"
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("titleSmall")
            font.weight: Theme.typeWeight("titleSmall")
            color: Theme.text
            text: Qt.formatDateTime(holder.now, "HH:mm")
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "notifications"
            size: "s"
            onClicked: if (holder.shell) holder.shell.togglePanel()
        }
    }

    OsdRow {
        id: osdRow
        visible: holder.mode === "osd"
        anchors.centerIn: parent
        kind: Osd.kind
        value: Osd.value
        muted: Osd.muted
    }

    NotifToastRow {
        id: notifRow
        visible: holder.mode === "notif"
        anchors.centerIn: parent
        current: Notif.current
    }
}
