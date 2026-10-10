import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui"

// Корневая страница панели: карточки Wi-Fi/Bluetooth со статусом,
// плитки быстрых настроек и уведомления.
ColumnLayout {
    id: rootPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === ""
    Layout.fillWidth: true
    spacing: 14

    // Большая карточка состояния сети: иконка в контейнере 40, заголовок и
    // живой статус. active — лёгкий accentContainer-оттенок и акцентная рамка.
    component NetCard: Item {
        id: netCard

        property string icon: ""
        property string title: ""
        property string status: ""
        property bool active: false

        signal tapped()

        Layout.fillWidth: true
        implicitHeight: Theme.dp(76)
        scale: netArea.pressed ? 0.98 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }

        Rectangle {
            id: netBg

            anchors.fill: parent
            radius: Theme.radiusLg
            color: netCard.active ? Theme.layer(Theme.bgTile, Theme.accentContainer, 0.18) : Theme.bgTile
            border.width: 1
            border.color: netCard.active ? Theme.accentBorder : Theme.a(Theme.outline, 0.25)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }
        }

        Rectangle { // state layer
            anchors.fill: netBg
            radius: netBg.radius
            color: Theme.text
            opacity: netArea.pressed ? Theme.statePressed : (netArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Theme.easeStandard
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(14)
            anchors.rightMargin: Theme.dp(14)
            spacing: Theme.dp(12)

            Rectangle { // контейнер иконки 40×40
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.dp(40)
                implicitHeight: Theme.dp(40)
                radius: Theme.radiusMd
                color: netCard.active ? Theme.accentContainer : Theme.bgTrack

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: netCard.icon
                    size: Theme.dp(20)
                    color: netCard.active ? Theme.fgAccentContainer : Theme.subtext

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durDefaultEffects
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.dp(2)

                Text {
                    Layout.fillWidth: true
                    text: netCard.title
                    color: Theme.text
                    elide: Text.ElideRight
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("titleSmall")
                    font.weight: Theme.typeWeight("titleSmall")
                }

                Text {
                    Layout.fillWidth: true
                    text: netCard.status
                    color: Theme.subtext
                    elide: Text.ElideRight
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }

        MouseArea {
            id: netArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingCursor
            onClicked: netCard.tapped()
        }
    }

    // ── Wi-Fi и Bluetooth: живое состояние без открытия страниц ───────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        NetCard {
            icon: "wifi"
            title: "Wi-Fi"
            active: Sys.wifiEnabled
            status: !Sys.wifiEnabled ? "Выключен"
                  : (Sys.activeSsid !== "" ? "Подключено: " + Sys.activeSsid : "Нет подключения")
            onTapped: {
                if (rootPage.win && rootPage.win.shell) {
                    Sys.refreshWifi();
                    rootPage.win.shell.togglePage("wifi");
                }
            }
        }

        NetCard {
            icon: "bluetooth"
            title: "Bluetooth"
            active: Sys.btEnabled
            status: !Sys.btEnabled ? "Выключен"
                  : (Sys.btConnected.length > 0
                     ? Sys.btConnected[0] + (Sys.btConnected.length > 1 ? " +" + (Sys.btConnected.length - 1) : "")
                     : "Включён")
            onTapped: {
                if (rootPage.win && rootPage.win.shell) {
                    Sys.startBtScan();
                    rootPage.win.shell.togglePage("bluetooth");
                }
            }
        }
    }

    // ── Плитки быстрых настроек (4 в ряд) ─────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 8
        rowSpacing: 8

        Tile { icon: "volume_up"; label: "Звук"; onTapped: if (win.shell) win.shell.togglePage("volume") }
        Tile { icon: "brightness_6"; label: "Яркость"; onTapped: if (win.shell) win.shell.togglePage("brightness") }
        Tile { icon: "do_not_disturb_on"; label: "DND"; active: Notif.dnd; onTapped: Prefs.set("dnd", !Notif.dnd) }
        Tile { icon: "timer"; label: "Таймеры"; onTapped: if (win.shell) win.shell.togglePage("timers") }
    }

    // ── Уведомления ───────────────────────────────────────────────────
    Card {
        visible: win && Notif.history.length > 0
        Layout.fillWidth: true
        title: "Уведомления"
        actionIcon: "delete"
        onActionClicked: Notif.clearAll()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: rootPage.win ? Notif.history.slice(0, 3) : []

                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0

                    Divider {
                        visible: index > 0
                        Layout.fillWidth: true
                        leftInset: Theme.dp(56)
                    }

                    NotifItem {
                        Layout.fillWidth: true
                        item: modelData
                        itemIndex: index
                    }
                }
            }
        }
    }
}
