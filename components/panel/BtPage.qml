import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."

ColumnLayout {
    id: btPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "bluetooth"
    Layout.fillWidth: true; spacing: 10
    ToggleRow {
        Layout.fillWidth: true
        label: "Bluetooth"; sub: Sys.btEnabled ? "включён" : "выключен"
        active: Sys.btEnabled
        onToggled: { Sys.toggleBt(); if (!Sys.btEnabled) Sys.refreshBt(); }
    }
    Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Устройства" }
    ListView {
        Layout.fillWidth: true; Layout.preferredHeight: 260
        model: Sys.btDevices; clip: true; spacing: 2
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: 40; radius: 10
            color: Theme.surface
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.text; text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext; text: modelData.mac }
            }
        }
    }
    Text {
        visible: Sys.btDevices.length === 0
        font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext
        text: "Устройств не найдено"
    }
}
