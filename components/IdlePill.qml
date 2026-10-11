import QtQuick
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

    // ── idle: раскладка + погода + воркспейсы + часы ──────────────────
    Row {
        id: idleRow
        visible: holder.mode === "idle"
        anchors.centerIn: parent
        spacing: Theme.dp(12)

        Rectangle { // чип раскладки клавиатуры
            id: layoutChip
            visible: Umbriel.keyboardLayout !== "" && Prefs.islandLayout
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: layoutText.implicitWidth + Theme.dp(16)
            implicitHeight: Theme.dp(22)
            radius: Theme.radiusPill
            color: Theme.alpha(Theme.accentContainer, 0.5)

            Text {
                id: layoutText
                anchors.centerIn: parent
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelMedium")
                font.weight: Theme.typeWeight("labelMedium")
                font.capitalization: Font.AllUppercase
                color: Theme.fgAccentContainer
                text: Umbriel.keyboardLayout
            }
        }

        Rectangle { // чип погоды: клик → вкладка «погода»
            id: weatherChip
            visible: Weather.hasData && isFinite(Weather.temp) && Prefs.islandWeather
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: weatherRow.implicitWidth + Theme.dp(16)
            implicitHeight: Theme.dp(22)
            radius: Theme.radiusPill
            // фон accentContainer + state layer композитом (Theme.layer), мягкая альфа
            color: Theme.alpha(Theme.layer(Theme.accentContainer, Theme.fgAccentContainer,
                               weatherArea.pressed ? Theme.statePressed
                                                   : (weatherArea.containsMouse ? Theme.stateHover : 0)), 0.5)
            scale: weatherArea.pressed ? 0.97 : 1

            Behavior on color { ColorAnimation { duration: Theme.ms(120) } }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(120)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: Theme.dp(4)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon
                    size: Theme.dp(13)
                    color: Theme.fgAccentContainer
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("titleSmall")
                    font.weight: Theme.typeWeight("titleSmall")
                    font.features: ({ "tnum": 1 })  // цифры одной ширины
                    color: Theme.fgAccentContainer
                    text: Math.round(Weather.temp) + "°"
                }
            }

            MouseArea {
                id: weatherArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (holder.shell) holder.shell.setTab("weather")
            }
        }

        WorkspacesRow { // воркспейсы — между чипами
            id: wsRow
            anchors.verticalCenter: parent.verticalCenter
            output: holder.output
            visible: Prefs.islandWorkspaces
        }

        Rectangle { // чип часов с секундами: клик → вкладка «управление»
            id: clockChip
            visible: Prefs.islandClock
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clockText.implicitWidth + Theme.dp(16)
            implicitHeight: Theme.dp(22)
            radius: Theme.radiusPill
            // фон accentContainer + state layer композитом (Theme.layer), мягкая альфа
            color: Theme.alpha(Theme.layer(Theme.accentContainer, Theme.fgAccentContainer,
                               clockArea.pressed ? Theme.statePressed
                                                 : (clockArea.containsMouse ? Theme.stateHover : 0)), 0.5)
            scale: clockArea.pressed ? 0.97 : 1

            Behavior on color { ColorAnimation { duration: Theme.ms(120) } }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(120)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Text {
                id: clockText
                anchors.centerIn: parent
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("titleSmall")
                font.weight: Theme.typeWeight("titleSmall")
                font.features: ({ "tnum": 1 })  // табличные цифры: ширина не дёргается каждую секунду
                color: Theme.fgAccentContainer
                text: Qt.formatDateTime(holder.now, Prefs.clockSeconds ? "HH:mm:ss" : "HH:mm")
            }

            MouseArea {
                id: clockArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (holder.shell) holder.shell.setTab("calendar")
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
