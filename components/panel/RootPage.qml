import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../core"
import ".."
import "../../ui"

// Корневая страница панели в анатомии Lucid control centre:
// слайдеры громкости/яркости (size m, inactive = withBlur(surfaceHighest)),
// плитки быстрого доступа как горизонтальные QuickTile Lucid (иконка-бейдж,
// заголовок/подпись, шеврон; ON — accentContainer, OFF — размытая
// surfaceHighest) и карточка уведомлений со строками NotifItem.
ColumnLayout {
    id: rootPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === ""
    Layout.fillWidth: true
    spacing: Theme.dp(12)

    // mm:ss для подписи плитки «Таймеры».
    function fmtTimer(sec) {
        const t = Math.max(0, Math.round(sec));
        const m = Math.floor(t / 60);
        const s = t % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Плитка быстрого доступа Lucid: бейдж-иконка 44dp слева, заголовок
    // titleSmall + подпись bodySmall, шеврон справа. OFF — размытая
    // surfaceHighest и стадионные торцы, ON — accentContainer и скругление
    // shapeLgInc (фирменный морф Lucid). Тап открывает страницу.
    component QuickTile: Item {
        id: qt

        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false

        signal tapped()

        Layout.fillWidth: true
        implicitHeight: Theme.dp(64)
        scale: qtArea.pressed ? 0.98 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }
        }

        Rectangle {
            id: qtBg

            anchors.fill: parent
            radius: qt.active ? Theme.shapeLgInc : Theme.pill(height)
            color: qt.active ? Theme.accentContainer : Theme.withBlur(Theme.mHighest)

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }

            StateLayer {
                id: qtArea

                radius: qtBg.radius
                tint: qt.active ? Theme.fgAccentContainer : Theme.text
                onClicked: qt.tapped()
            }
        }

        Rectangle { // бейдж-иконка 44dp
            id: badge

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(44)
            height: Theme.dp(44)
            radius: width / 2
            color: qt.active ? Theme.alpha(Theme.fgAccentContainer, 0.14) : Theme.alpha(Theme.text, 0.08)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }

            Icon {
                anchors.centerIn: parent
                name: qt.icon
                size: Theme.dp(22)
                fill: qt.active ? 1 : 0
                color: qt.active ? Theme.fgAccentContainer : Theme.text

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }
        }

        Column { // заголовок + подпись
            anchors.left: badge.right
            anchors.leftMargin: Theme.dp(10)
            anchors.right: chevron.left
            anchors.rightMargin: Theme.dp(2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            LText {
                width: parent.width
                role: "titleSmall"
                weight: 600
                text: qt.label
                color: qt.active ? Theme.fgAccentContainer : Theme.text
                elide: Text.ElideRight
            }

            LText {
                width: parent.width
                visible: text !== ""
                role: "bodySmall"
                text: qt.subtitle
                color: qt.active ? Theme.alpha(Theme.fgAccentContainer, 0.78) : Theme.subtext
                elide: Text.ElideRight
            }
        }

        Icon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Theme.dp(20)
            color: qt.active ? Theme.fgAccentContainer : Theme.subtext
        }
    }

    // ── слайдеры громкости и яркости (Lucid size m) ────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(10)

        Slider {
            Layout.fillWidth: true
            size: "m"
            icon: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio.muted ? "volume_off" : "volume_up"
            value: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0
            inactiveColor: Theme.withBlur(Theme.mHighest)
            onMoved: (v) => { if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.volume = v; }
            onCommitted: (v) => { if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.volume = v; }
            onIconClicked: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("volume")
        }

        Slider {
            Layout.fillWidth: true
            size: "m"
            icon: "brightness_6"
            value: Sys.brightnessFraction
            inactiveColor: Theme.withBlur(Theme.mHighest)
            onCommitted: (v) => { Sys.setBrightnessPct(v * 100); }
            onIconClicked: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("brightness")
        }
    }

    // ── плитки быстрого доступа: 2 колонки ─────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.dp(10)
        rowSpacing: Theme.dp(10)

        QuickTile {
            icon: "wifi"
            label: "Wi-Fi"
            active: Sys.wifiEnabled && Sys.activeSsid !== ""
            subtitle: Sys.activeSsid !== "" ? Sys.activeSsid : (Sys.wifiEnabled ? "Не подключено" : "Выключен")
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

    // ── уведомления: карточка видна только при наличии истории ─────────
    Card {
        visible: Notif.history.length > 0
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
