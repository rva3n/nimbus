import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
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

    // Активный аудиовыход для подписи плитки «Звук».
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property string sinkLabel: sink ? (sink.description || sink.name || "Вывод") : "Вывод"

    // Батарея: на десктопе её нет — кольцо аккуратно скрывается.
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isPresent
        && String(battery.iconName).indexOf("missing") === -1
    readonly property real batteryFrac: hasBattery ? (battery.percentage || 0) : 0

    // mm:ss для подписи плитки «Таймеры».
    function fmtTimer(sec) {
        const t = Math.max(0, Math.round(sec));
        const m = Math.floor(t / 60);
        const s = t % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

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

    // Плитка быстрого доступа: круглая иконка-контейнер сверху, жирная подпись
    // и тусклый статус снизу. active — залитый акцентом фон, как у включённого
    // Wi-Fi: контейнер и текст переходят в fgAccentContainer.
    component QuickTile: Item {
        id: qt

        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false

        signal tapped()

        Layout.fillWidth: true
        implicitHeight: Theme.dp(88)
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
            radius: Theme.radiusLg
            color: qt.active ? Theme.accentContainer
                 : (qtArea.pressed ? Theme.bgActive : (qtArea.containsMouse ? Theme.bgHover : Theme.bgTile))
            border.width: 1
            border.color: qt.active ? Theme.accentBorder : Theme.a(Theme.outline, 0.25)

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

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.dp(4)

            Rectangle { // круглая иконка-контейнер 40×40
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Theme.dp(40)
                implicitHeight: Theme.dp(40)
                radius: width / 2
                color: qt.active ? Theme.fgAccentContainer : Theme.accentContainer

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: qt.icon
                    size: Theme.dp(20)
                    color: qt.active ? Theme.accentContainer : Theme.fgAccentContainer

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durDefaultEffects
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: qt.width - Theme.dp(10)
                text: qt.label
                elide: Text.ElideRight
                color: qt.active ? Theme.fgAccentContainer : Theme.text
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelLarge")
                font.weight: Theme.typeWeight("labelLarge")

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: qt.width - Theme.dp(10)
                text: qt.subtitle
                elide: Text.ElideRight
                color: qt.active ? Theme.a(Theme.fgAccentContainer, 0.85) : Theme.subtextDim
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
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

    // ── Плитки быстрых настроек (4 в ряд, материал) ───────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 8
        rowSpacing: 8

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
            subtitle: Notif.dnd ? "Включён" : "Выключен"
            active: Notif.dnd
            onTapped: Prefs.set("dnd", !Notif.dnd)
        }

        QuickTile {
            icon: "timer"
            label: "Таймеры"
            subtitle: Chrono.running ? rootPage.fmtTimer(Chrono.remaining) : "Нет активных"
            active: Chrono.running
            onTapped: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("timers")
        }
    }

    // ── Система: четыре кольцевых датчика ─────────────────────────────
    Card {
        Layout.fillWidth: true
        title: "Система"

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(4)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.dp(4)

                Ring {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Theme.dp(58)
                    implicitHeight: Theme.dp(58)
                    thickness: Theme.dp(6)
                    value: SysStats.cpu
                    color: Theme.accent
                    label: Math.round(SysStats.cpu * 100) + "%"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "CPU"
                    color: Theme.subtextDim
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("labelSmall")
                    font.weight: Theme.typeWeight("labelSmall")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.dp(4)

                Ring {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Theme.dp(58)
                    implicitHeight: Theme.dp(58)
                    thickness: Theme.dp(6)
                    value: SysStats.memFrac
                    color: Theme.secondary
                    label: Math.round(SysStats.memFrac * 100) + "%"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Память"
                    color: Theme.subtextDim
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("labelSmall")
                    font.weight: Theme.typeWeight("labelSmall")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.dp(4)

                Ring {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Theme.dp(58)
                    implicitHeight: Theme.dp(58)
                    thickness: Theme.dp(6)
                    value: Math.max(0, Math.min(1, SysStats.tempC / 100))
                    color: Theme.tertiary
                    label: SysStats.tempC >= 0 && isFinite(SysStats.tempC)
                           ? Math.round(SysStats.tempC) + "°" : "—"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Темп"
                    color: Theme.subtextDim
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("labelSmall")
                    font.weight: Theme.typeWeight("labelSmall")
                }
            }

            ColumnLayout {
                visible: rootPage.hasBattery
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.dp(4)

                Ring {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Theme.dp(58)
                    implicitHeight: Theme.dp(58)
                    thickness: Theme.dp(6)
                    value: rootPage.batteryFrac
                    color: Theme.accent
                    label: Math.round(rootPage.batteryFrac * 100) + "%"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Батарея"
                    color: Theme.subtextDim
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("labelSmall")
                    font.weight: Theme.typeWeight("labelSmall")
                }
            }
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
