import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
import ".."

// Bluetooth: карточка-переключатель радио и карточка найденных устройств.
ColumnLayout {
    id: btPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "bluetooth"
    Layout.fillWidth: true; spacing: 10

    // переключатель модуля
    Card {
        Layout.fillWidth: true
        pad: Theme.dp(6)

        ToggleRow {
            Layout.fillWidth: true
            icon: "bluetooth"
            label: "Bluetooth"; sub: Sys.btEnabled ? "включён" : "выключен"
            active: Sys.btEnabled
            onToggled: { Sys.toggleBt(); if (!Sys.btEnabled) Sys.refreshBt(); }
        }
    }

    // устройства: заголовок секции и сканирование — в шапке Card
    Card {
        Layout.fillWidth: true
        title: "Устройства"
        actionIcon: "refresh"
        onActionClicked: Sys.startBtScan()

        ListView {
            Layout.fillWidth: true; Layout.preferredHeight: 260
            model: Sys.btDevices
            clip: true; spacing: Theme.dp(4)

            delegate: Rectangle {
                id: btRow
                required property var modelData
                required property int index
                width: ListView.view.width; height: Theme.dp(56)
                radius: Theme.radiusMd
                color: btMouse.containsMouse ? Theme.bgHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.dp(8); anchors.rightMargin: Theme.dp(8)
                    spacing: Theme.dp(8)

                    Rectangle { // ведущая иконка 40×40
                        implicitWidth: Theme.dp(40); implicitHeight: Theme.dp(40)
                        radius: Theme.radiusMd
                        color: Theme.bgTrack

                        Icon {
                            anchors.centerIn: parent
                            name: "bluetooth"; size: Theme.dp(20)
                            color: Theme.subtext
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
                            font.weight: Theme.typeWeight("bodyLarge"); color: Theme.text
                            text: btRow.modelData.name
                        }
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
                            text: btRow.modelData.mac
                        }
                    }
                }

                MouseArea {
                    id: btMouse
                    anchors.fill: parent; hoverEnabled: true
                }
            }
        }

        Text {
            visible: Sys.btDevices.length === 0
            Layout.fillWidth: true
            Layout.leftMargin: Theme.dp(8)
            Layout.bottomMargin: Theme.dp(4)
            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
            text: "Устройств не найдено"
        }
    }
}
