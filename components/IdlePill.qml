import QtQuick
import Quickshell
import "../core"
import "../ui"

// Содержимое острова для idle/osd/notif. Внешнюю капсулу (фон Theme.bg,
// рамку, радиус) рисует сам Island, поэтому своего общего фона здесь нет:
// idle — один ряд [раскладка][погода][воркспейсы][часы],
// osd/notif — строки. API: mode/now/output/shell.
Item {
    id: holder
    property string mode: "idle"
    property date now: new Date()
    property string output: ""
    property var shell: null

    implicitWidth: mode === "notif" ? notifRow.implicitWidth
                 : mode === "osd" ? osdRow.implicitWidth
                 : idleRow.implicitWidth
    // notif ≥40 — тосту не тесно; osd 34, idle 28 (остров = +6)
    implicitHeight: mode === "notif" ? Math.max(Theme.dp(40), notifRow.implicitHeight)
                  : mode === "osd" ? Theme.dp(34)
                  : Theme.dp(28)

    // ── idle: раскладка + погода + воркспейсы + часы + трей ────────────
    // Чипы — Lucid-пилюли: без обводок, заливка ролью (bgTile/accent),
    // взаимодействие — StateLayer. Высота 24 внутри 28-полосы idle.
    Row {
        id: idleRow
        visible: holder.mode === "idle"
        anchors.centerIn: parent
        spacing: Theme.dp(6)

        // раскладка клавиатуры: компактный кликабельный чип (bgTile)
        Item {
            id: layoutChip
            visible: Umbriel.keyboardLayout !== "" && Prefs.islandLayout
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: layoutText.implicitWidth + Theme.dp(18)
            implicitHeight: Theme.dp(24)
            scale: layoutArea.pressed ? 0.96 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastEffects
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: Theme.bgTile
                StateLayer {
                    id: layoutArea
                    radius: parent.radius
                    onClicked: Quickshell.execDetached(["umbriel", "msg", "keyboard-layout-next"])
                }
            }

            LText {
                id: layoutText
                anchors.centerIn: parent
                role: "labelMedium"
                color: Theme.subtext
                text: Umbriel.keyboardLayout
                font.capitalization: Font.AllUppercase
            }
        }

        // погода: чип icon + temp (bgTile), клик → вкладка «погода»
        Item {
            id: weatherChip
            visible: Weather.hasData && isFinite(Weather.temp) && Prefs.islandWeather
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: weatherRow.implicitWidth + Theme.dp(18)
            implicitHeight: Theme.dp(24)
            scale: weatherArea.pressed ? 0.96 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastEffects
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: Theme.bgTile
                StateLayer {
                    id: weatherArea
                    radius: parent.radius
                    onClicked: if (holder.shell) holder.shell.setTab("weather")
                }
            }

            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: Theme.dp(4)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon
                    size: Theme.dp(14)
                    color: Theme.primary
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    tabular: true
                    color: Theme.text
                    text: Math.round(Weather.temp) + "°"
                }
            }
        }

        WorkspacesRow { // воркспейсы — между чипами
            id: wsRow
            anchors.verticalCenter: parent.verticalCenter
            output: holder.output
            visible: Prefs.islandWorkspaces
        }

        // часы: залитый акцентный чип (Lucid clock pill), табличные цифры
        Item {
            id: clockChip
            visible: Prefs.islandClock
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clockText.implicitWidth + Theme.dp(20)
            implicitHeight: Theme.dp(24)
            scale: clockArea.pressed ? 0.96 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastEffects
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: Theme.primary
                StateLayer {
                    id: clockArea
                    radius: parent.radius
                    tint: Theme.fgAccent
                    onClicked: if (holder.shell) holder.shell.setTab("calendar")
                }
            }

            LText {
                id: clockText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Math.round(Theme.digitCenterOffset * size)
                role: "labelLarge"
                weight: 700
                rounded: 100
                tabular: true
                color: Theme.fgAccent
                text: Qt.formatDateTime(holder.now, Prefs.clockSeconds ? "HH:mm:ss" : "HH:mm")
            }
        }

        // Системный трей — правый край idle-ряда, после часов. Отдельный файл
        // TrayRow.qml: грузим через Loader с явным source, потому что qmldir
        // (его здесь не трогаем) не объявляет TrayRow. Ширину берём с
        // содержимого: на пустом трее она 0 и капсула не занимает места.
        Loader {
            id: trayLoader
            anchors.verticalCenter: parent.verticalCenter
            source: "TrayRow.qml"
            active: Prefs.islandTray
            width: item ? item.implicitWidth : 0
            visible: width > 0
            // клик по капсуле открывает вид острова «трей»
            Binding { target: trayLoader.item; property: "shell"; value: holder.shell; when: trayLoader.item !== null }
        }
    }

    // ── OSD: только содержимое, фон рисует Island ─────────────────────
    OsdRow {
        id: osdRow
        visible: holder.mode === "osd"
        anchors.centerIn: parent
        kind: Osd.kind
        value: Osd.value
        muted: Osd.muted
    }

    // ── Уведомление: только содержимое, фон рисует Island ─────────────
    NotifToastRow {
        id: notifRow
        visible: holder.mode === "notif"
        anchors.centerIn: parent
        current: Notif.current
    }
}
