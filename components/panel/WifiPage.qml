import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
import ".."

// Wi-Fi: карточка-переключатель радио и карточка списка сетей с паролем.
ColumnLayout {
    id: wifiPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "wifi"
    Layout.fillWidth: true; spacing: 10

    // переключатель модуля
    Card {
        Layout.fillWidth: true
        pad: Theme.dp(6)

        ToggleRow {
            Layout.fillWidth: true
            icon: "wifi"
            label: "Wi-Fi"; sub: Sys.wifiEnabled ? "включён" : "выключен"
            active: Sys.wifiEnabled
            onToggled: { Sys.toggleWifi(); if (!Sys.wifiEnabled) Sys.refreshWifi(); }
        }
    }

    // сети: заголовок секции и обновление — в шапке Card
    Card {
        Layout.fillWidth: true
        title: "Сети"
        actionIcon: "refresh"
        onActionClicked: Sys.refreshWifi()

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: win && win.wifiSel === "" ? 300 : 200
            model: win ? win.wifiList : []
            clip: true; spacing: 0

            delegate: Rectangle {
                id: netRow
                required property var modelData
                required property int index
                width: ListView.view.width; height: Theme.dp(56)
                radius: Theme.radiusMd
                readonly property bool sel: !!(win && win.wifiSel === modelData.ssid)
                color: netRow.sel ? Theme.accentContainer
                     : (netMouse.containsMouse ? Theme.bgHover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }

                Divider {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    visible: netRow.index > 0
                    leftInset: Theme.dp(56)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.dp(8); anchors.rightMargin: Theme.dp(8)
                    spacing: Theme.dp(8)

                    Rectangle { // ведущая иконка сети 40×40
                        implicitWidth: Theme.dp(40); implicitHeight: Theme.dp(40)
                        radius: Theme.radiusMd
                        color: netRow.sel ? Theme.accentContainer : Theme.bgTrack

                        Icon {
                            anchors.centerIn: parent
                            name: "wifi"; size: Theme.dp(20)
                            color: netRow.sel ? Theme.fgAccentContainer : Theme.subtext
                        }
                    }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
                        font.weight: Theme.typeWeight("bodyLarge")
                        color: netRow.sel ? Theme.fgAccentContainer : Theme.text
                        text: netRow.modelData.ssid
                    }
                    Icon {
                        visible: !!(netRow.modelData.security && netRow.modelData.security !== "--" && netRow.modelData.security !== "")
                        name: "lock"; size: Theme.dp(14)
                        color: netRow.sel ? Theme.fgAccentContainer : Theme.subtext
                    }
                    Text {
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall")
                        color: netRow.sel ? Theme.fgAccentContainer : Theme.subtext
                        text: netRow.modelData.signal + "%"
                    }
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const sec = netRow.modelData.security;
                        if (!sec || sec === "" || sec === "--") {
                            Sys.connectWifi(netRow.modelData.ssid, "");
                            if (win.shell) win.shell.setPage("");
                        } else {
                            win.wifiSel = netRow.modelData.ssid;
                            wifiPassInput.text = "";
                            wifiPassInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // пароль выбранной сети
        RowLayout {
            visible: win !== null && win.wifiSel !== ""
            Layout.fillWidth: true
            Layout.leftMargin: Theme.dp(8); Layout.rightMargin: Theme.dp(8)
            Layout.topMargin: Theme.dp(2)
            spacing: Theme.dp(8)
            TextField {
                id: wifiPassInput
                Layout.fillWidth: true
                placeholder: "Пароль: " + (win ? win.wifiSel : "")
                echoMode: TextInput.Password
                onAccepted: if (win) win.submitWifi(text)
            }
            IconButton {
                icon: "check"; variant: "filled"
                onClicked: if (win) win.submitWifi(wifiPassInput.text)
            }
        }
    }
}
