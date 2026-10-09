import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
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

    // заголовок секции + повторное сканирование
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.dp(2)
        Text {
            Layout.fillWidth: true
            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("labelMedium")
            font.weight: Theme.typeWeight("labelMedium"); color: Theme.subtext
            text: "Устройства"
        }
        IconButton { icon: "refresh"; onClicked: Sys.startBtScan() }
    }

    ListView {
        Layout.fillWidth: true; Layout.preferredHeight: 260
        model: Sys.btDevices; clip: true; spacing: Theme.dp(4)
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: Theme.dp(56)
            radius: Theme.radiusMd
            color: Theme.bgTile
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(16); anchors.rightMargin: Theme.dp(16); spacing: Theme.dp(12)
                Icon { name: "bluetooth"; size: Theme.dp(20); color: Theme.accent }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
                        font.weight: Theme.typeWeight("bodyLarge"); color: Theme.text
                        text: modelData.name
                    }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
                        text: modelData.mac
                    }
                }
            }
        }
    }

    Text {
        visible: Sys.btDevices.length === 0
        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
        font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
        text: "Устройств не найдено"
    }
}
