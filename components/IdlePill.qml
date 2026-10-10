import QtQuick
import "../core"
import "../ui"

// Содержимое острова для idle/osd/notif. Внешнюю капсулу (фон Theme.bg,
// рамку, радиус) рисует сам Island, поэтому своего общего фона здесь нет:
// idle — один ряд [чип погоды][воркспейсы][чип часов], osd/notif — строки.
// API: mode/now/output/shell.
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

    // ── idle: погода + воркспейсы + часы в одном ряду ─────────────────
    Row {
        id: idleRow
        visible: holder.mode === "idle"
        anchors.centerIn: parent
        spacing: Theme.dp(12)

        Rectangle { // чип погоды: клик → вкладка «погода»
            id: weatherChip
            visible: Weather.hasData
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: weatherRow.implicitWidth + Theme.dp(20)
            implicitHeight: Theme.dp(24)
            radius: Theme.radiusPill
            // фон accentContainer + state layer композитом (Theme.layer)
            color: Theme.layer(Theme.accentContainer, Theme.fgAccentContainer,
                               weatherArea.pressed ? Theme.statePressed
                                                   : (weatherArea.containsMouse ? Theme.stateHover : 0))
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
        }

        Rectangle { // чип часов с секундами: клик → вкладка «управление»
            id: clockChip
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clockText.implicitWidth + Theme.dp(20)
            implicitHeight: Theme.dp(24)
            radius: Theme.radiusPill
            // фон accentContainer + state layer композитом (Theme.layer)
            color: Theme.layer(Theme.accentContainer, Theme.fgAccentContainer,
                               clockArea.pressed ? Theme.statePressed
                                                 : (clockArea.containsMouse ? Theme.stateHover : 0))
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
                color: Theme.fgAccentContainer
                text: Qt.formatDateTime(holder.now, "HH:mm:ss")
            }

            MouseArea {
                id: clockArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (holder.shell) holder.shell.setTab("control")
            }
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
