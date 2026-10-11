import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../core"
import ".."
import "../../ui"

// Корневая страница панели: сетка плиток быстрых настроек (Wi-Fi, Bluetooth,
// звук, яркость, DND, таймеры) и уведомления. Дизайн — как в yoru: тёмная
// карточка, безрамочные плитки 2×N, круглые контейнеры иконок.
ColumnLayout {
    id: rootPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === ""
    Layout.fillWidth: true
    spacing: 14

    // Активный аудиовыход для подписи плитки «Звук».
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property string sinkLabel: sink ? (sink.description || sink.name || "Вывод") : "Вывод"

    // mm:ss для подписи плитки «Таймеры».
    function fmtTimer(sec) {
        const t = Math.max(0, Math.round(sec));
        const m = Math.floor(t / 60);
        const s = t % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Плитка быстрого доступа в стиле yoru: круглый контейнер иконки слева,
    // подпись и статус справа. OFF — едва заметный тёмный фон, ON — мягкий
    // акцентный оттенок. Без рамок.
    component QuickTile: Item {
        id: qt

        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false

        signal tapped()

        Layout.fillWidth: true
        implicitHeight: Theme.dp(76)
        scale: qtArea.pressed ? 0.97 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }

        Rectangle {
            id: qtBg

            anchors.fill: parent
            radius: Math.max(Theme.radiusLg, Theme.dp(20))
            color: qt.active ? Theme.alpha(Theme.accent, 0.16) : Theme.bgTile

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }
        }

        Rectangle { // state layer
            anchors.fill: qtBg
            radius: qtBg.radius
            color: Theme.text
            opacity: qtArea.pressed ? Theme.statePressed : (qtArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Theme.easeStandard
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(12)
            anchors.rightMargin: Theme.dp(12)
            spacing: Theme.dp(12)

            Rectangle { // круглый контейнер иконки 36×36
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.dp(36)
                implicitHeight: Theme.dp(36)
                radius: width / 2
                color: qt.active ? Theme.alpha(Theme.accent, 0.30) : Theme.bgTrack

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: qt.icon
                    size: Theme.dp(20)
                    color: qt.active ? Theme.accent : Theme.subtext

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
                    text: qt.label
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("labelLarge")
                    font.weight: Theme.typeWeight("labelLarge")
                }

                Text {
                    Layout.fillWidth: true
                    text: qt.subtitle
                    elide: Text.ElideRight
                    color: Theme.subtextDim
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }

        MouseArea {
            id: qtArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingCursor
            onClicked: qt.tapped()
        }
    }

    // ── Плитки быстрых настроек: 2 колонки × N строк, как в yoru ──────
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        QuickTile {
            icon: "wifi"
            label: "Wi-Fi"
            active: Sys.wifiEnabled && Sys.activeSsid !== ""
            subtitle: Sys.activeSsid !== "" ? Sys.activeSsid : "Нет подключения"
            onTapped: {
                if (rootPage.win && rootPage.win.shell) {
                    Sys.refreshWifi();
                    rootPage.win.shell.togglePage("wifi");
                }
            }
        }

        QuickTile {
            icon: "bluetooth"
            label: "Bluetooth"
            active: Sys.btEnabled
            subtitle: Sys.btEnabled ? "Включён" : "Выключен"
            onTapped: {
                if (rootPage.win && rootPage.win.shell) {
                    Sys.startBtScan();
                    rootPage.win.shell.togglePage("bluetooth");
                }
            }
        }

        QuickTile {
            icon: "volume_up"
            label: "Звук"
            subtitle: rootPage.sinkLabel
            onTapped: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("volume")
        }

        QuickTile {
            icon: "brightness_6"
            label: "Яркость"
            subtitle: Math.round(Sys.brightnessFraction * 100) + "%"
            onTapped: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("brightness")
        }

        QuickTile {
            icon: "do_not_disturb_on"
            label: "DND"
            active: Notif.dnd
            subtitle: Notif.dnd ? "Включён" : "Выключен"
            onTapped: Prefs.set("dnd", !Notif.dnd)
        }

        QuickTile {
            icon: "timer"
            label: "Таймеры"
            active: Chrono.running
            subtitle: Chrono.running ? rootPage.fmtTimer(Chrono.remaining) : "Нет активных"
            onTapped: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("timers")
        }
    }

    // ── Уведомления ───────────────────────────────────────────────────
    Card {
        Layout.fillWidth: true
        title: "Уведомления"
        actionIcon: Notif.history.length > 0 ? "delete" : ""
        onActionClicked: Notif.clearAll()

        // пустое состояние: карточка видна всегда
        ColumnLayout {
            visible: !Notif.history || Notif.history.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(10)
            Layout.bottomMargin: Theme.dp(10)
            spacing: Theme.dp(6)

            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: "bedtime"
                size: Theme.dp(36)
                color: Theme.subtextDim
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Всё тихо"
                color: Theme.subtextDim
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium")
            }
        }

        ColumnLayout {
            visible: Notif.history && Notif.history.length > 0
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
