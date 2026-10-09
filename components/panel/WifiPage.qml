import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
import ".."

ColumnLayout {
    id: wifiPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "wifi"
    Layout.fillWidth: true; spacing: 10

    ToggleRow {
        Layout.fillWidth: true
        label: "Wi-Fi"; sub: Sys.wifiEnabled ? "включён" : "выключен"
        active: Sys.wifiEnabled
        onToggled: { Sys.toggleWifi(); if (!Sys.wifiEnabled) Sys.refreshWifi(); }
    }

    // заголовок секции + обновление списка сетей
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.dp(2)
        Text {
            Layout.fillWidth: true
            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("labelMedium")
            font.weight: Theme.typeWeight("labelMedium"); color: Theme.subtext
            text: "Сети"
        }
        IconButton { icon: "refresh"; onClicked: Sys.refreshWifi() }
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: win && win.wifiSel === "" ? 300 : 200
        model: win ? win.wifiList : []; clip: true; spacing: Theme.dp(4)
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: Theme.dp(48)
            radius: Theme.radiusMd
            color: win && win.wifiSel === modelData.ssid ? Theme.accentContainer
                 : (netMouse.containsMouse ? Theme.bgHover : Theme.bgTile)
            Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(16); anchors.rightMargin: Theme.dp(16); spacing: Theme.dp(12)
                Icon { name: "wifi"; size: Theme.dp(18); color: Theme.subtext }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
                    font.weight: Theme.typeWeight("bodyLarge"); color: Theme.text
                    text: modelData.ssid
                }
                Icon {
                    visible: modelData.security && modelData.security !== "--" && modelData.security !== ""
                    name: "lock"; size: Theme.dp(14); color: Theme.subtext
                }
                Text {
                    font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
                    text: modelData.signal + "%"
                }
            }
            MouseArea {
                id: netMouse; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const sec = modelData.security;
                    if (!sec || sec === "" || sec === "--") {
                        Sys.connectWifi(modelData.ssid, "");
                        if (win.shell) win.shell.setPage("");
                    } else {
                        win.wifiSel = modelData.ssid;
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
