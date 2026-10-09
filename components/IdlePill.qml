import QtQuick
import QtQuick.Layouts
import "../core"

// Idle / OSD / notification pill: compactRow + osdRow + notifRow.
Item {
    id: holder
    property string mode: "idle"
    property date now: new Date()
    property string output: ""
    property var shell: null
    implicitWidth: mode === "notif" ? notifRow.implicitWidth
                 : mode === "osd" ? osdRow.implicitWidth
                 : compactRow.implicitWidth
    implicitHeight: 22

    RowLayout {
        id: compactRow
        visible: holder.mode === "idle"
        anchors.centerIn: parent
        spacing: Theme.spacing
        WorkspacesRow { output: holder.output }
        Text {
            font.family: Theme.font; font.pixelSize: Theme.fontSize; color: Theme.text
            text: Qt.formatDateTime(holder.now, "HH:mm")
        }
        IconBtn { glyph: "\uf0f3"; onClicked: if (holder.shell) holder.shell.togglePanel() }
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
