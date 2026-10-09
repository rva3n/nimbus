import QtQuick
import QtQuick.Layouts
import "../../core"
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
    Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Сети" }
    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: win && win.wifiSel === "" ? 300 : 200
        model: win ? win.wifiList : []; clip: true; spacing: 2
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: 40; radius: 10
            color: wifiMouse.containsMouse ? Theme.surfaceHi : Theme.surface
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.text; text: modelData.ssid; Layout.fillWidth: true; elide: Text.ElideRight }
                Text {
                    visible: modelData.security && modelData.security !== "--" && modelData.security !== ""
                    font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "\uf023"
                }
                Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: modelData.signal + "%" }
            }
            MouseArea {
                id: wifiMouse; anchors.fill: parent; hoverEnabled: true
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
    Rectangle {
        visible: win !== null && win.wifiSel !== ""
        Layout.fillWidth: true; implicitHeight: 42; radius: 10
        color: Theme.surface
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6; spacing: 8
            TextInput {
                id: wifiPassInput
                Layout.fillWidth: true
                font.family: Theme.font; font.pixelSize: 13; color: Theme.text
                echoMode: TextInput.Password
                clip: true; selectByMouse: true
                onAccepted: win.submitWifi(text)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: wifiPassInput.text === ""
                    text: "Пароль: " + (win ? win.wifiSel : "")
                    color: Theme.a(Theme.subtext, 0.5); font: wifiPassInput.font
                }
            }
            IconBtn { glyph: "\uf00c"; onClicked: win.submitWifi(wifiPassInput.text) }
        }
    }
}
