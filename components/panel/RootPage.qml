import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui"

// Корневая страница панели: сводка погоды, плитки быстрых настроек,
// медиа-карточка и уведомления. Группы — в ui/Card.
ColumnLayout {
    id: rootPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "" && win.shell && win.shell.panelTab === "control"
    Layout.fillWidth: true
    spacing: 14

    // ── Погода: сводка целиком кликабельна, ведёт на страницу «Погода» ─
    Card {
        id: weatherCard

        visible: Weather.hasData
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
            implicitHeight: wpRow.implicitHeight

            Rectangle { // state layer
                anchors.fill: parent
                radius: Theme.radiusLg
                color: Theme.text
                opacity: wpArea.containsMouse ? Theme.stateHover : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(100)
                        easing.type: Theme.easeStandard
                    }
                }
            }

            RowLayout {
                id: wpRow

                anchors.fill: parent
                spacing: Theme.dp(12)

                Icon {
                    Layout.alignment: Qt.AlignVCenter
                    name: Weather.icon
                    size: Theme.dp(28)
                    color: Theme.accent
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Math.round(Weather.temp) + "°"
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("headlineSmall")
                    font.weight: Theme.typeWeight("headlineSmall")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: Weather.desc
                        color: Theme.subtext
                        elide: Text.ElideRight
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall")
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Weather.place
                        color: Theme.subtextDim
                        elide: Text.ElideRight
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("labelSmall")
                        font.weight: Theme.typeWeight("labelSmall")
                    }
                }

                Icon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "chevron_right"
                    size: Theme.dp(20)
                    color: Theme.subtextDim
                }
            }

            MouseArea {
                id: wpArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingCursor
                onClicked: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.setTab("weather")
            }
        }
    }

    // ── Ошибка погоды: компактная строка + обновление ─────────────────
    Rectangle {
        visible: Weather.error !== ""
        Layout.fillWidth: true
        implicitHeight: Theme.dp(44)
        radius: Theme.radiusLg
        color: Theme.errorContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(12)
            anchors.rightMargin: Theme.dp(6)
            spacing: Theme.dp(8)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: "error"
                size: Theme.dp(18)
                color: Theme.fgErrorContainer
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: Weather.error
                color: Theme.fgErrorContainer
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }

            Item { // кнопка «обновить» в error-тоне
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.dp(32)
                implicitHeight: Theme.dp(32)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusPill
                    color: Theme.fgErrorContainer
                    opacity: errArea.pressed ? Theme.statePressed : (errArea.containsMouse ? Theme.stateHover : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(100)
                            easing.type: Theme.easeStandard
                        }
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: Theme.dp(18)
                    color: Theme.fgErrorContainer
                }

                MouseArea {
                    id: errArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingCursor
                    onClicked: Weather.refresh()
                }
            }
        }
    }

    // ── Плитки быстрых настроек (3 в ряд) ─────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 8
        rowSpacing: 8

        Tile { icon: "wifi"; label: "Wi-Fi"; active: Sys.wifiEnabled; onTapped: if (win.shell) { Sys.refreshWifi(); win.shell.togglePage("wifi"); } }
        Tile { icon: "bluetooth"; label: "Bluetooth"; active: Sys.btEnabled; onTapped: if (win.shell) { Sys.startBtScan(); win.shell.togglePage("bluetooth"); } }
        Tile { icon: "volume_up"; label: "Звук"; onTapped: if (win.shell) win.shell.togglePage("volume") }
        Tile { icon: "brightness_6"; label: "Яркость"; onTapped: if (win.shell) win.shell.togglePage("brightness") }
        Tile { icon: "do_not_disturb_on"; label: "DND"; active: Notif.dnd; onTapped: Notif.dnd = !Notif.dnd }
        Tile { icon: "image"; label: "Обои"; onTapped: if (win.shell) win.shell.togglePage("wallpapers") }
        Tile { icon: "mood"; label: "Эмодзи"; onTapped: if (win.shell) win.shell.openLauncher("emoji") }
        Tile { icon: "monitor_heart"; label: "Система"; onTapped: if (win.shell) win.shell.setTab("system") }
        Tile { icon: "timer"; label: "Таймеры"; onTapped: if (win.shell) win.shell.togglePage("timers") }
    }

    // Медиа-карточка — отдельный компонент; props не меняем.
    MediaCard {
        visible: win && win.player !== null
        Layout.fillWidth: true
        artFile: win ? win.artFile : ""
        artUrl: win ? win.artUrl : ""
        player: win ? win.player : null
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
