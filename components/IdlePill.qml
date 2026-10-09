import QtQuick
import "../core"
import "../ui"

// Idle/OSD/уведомления: в idle — три раздельные пилюли (воркспейсы, погода,
// часы), OSD и тост — внутри одной пилюли того же вида. Фон рисуем сами:
// контейнер острова в idle прозрачный. API: mode/now/output/shell.
Item {
    id: holder
    property string mode: "idle"
    property date now: new Date()
    property string output: ""
    property var shell: null

    implicitWidth: mode === "notif" ? notifPill.implicitWidth
                 : mode === "osd" ? osdPill.implicitWidth
                 : idleRow.implicitWidth
    implicitHeight: Theme.dp(30)

    // ── idle: воркспейсы + погода + часы, каждая в своей пилюле ───────
    Row {
        id: idleRow
        visible: holder.mode === "idle"
        anchors.centerIn: parent
        spacing: Theme.dp(6)

        Rectangle { // воркспейсы Umbriel
            id: wsPill
            visible: wsRow.items.length > 0
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: wsRow.implicitWidth + Theme.dp(20)
            implicitHeight: Theme.dp(30)
            radius: Theme.radiusPill
            color: Theme.bgOpaque
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)

            WorkspacesRow {
                id: wsRow
                anchors.centerIn: parent
                output: holder.output
            }
        }

        Rectangle { // погода: клик → панель на вкладке «погода»
            id: weatherPill
            visible: Weather.hasData
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: weatherRow.implicitWidth + Theme.dp(20)
            implicitHeight: Theme.dp(30)
            radius: Theme.radiusPill
            color: Theme.bgOpaque
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)
            scale: weatherArea.pressed ? 0.98 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(120)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Rectangle { // hover/нажатие — state layer
                anchors.fill: parent
                radius: parent.radius
                color: Theme.text
                opacity: weatherArea.pressed ? Theme.statePressed : (weatherArea.containsMouse ? Theme.stateHover : 0)

                Behavior on opacity { NumberAnimation { duration: Theme.ms(120) } }
            }

            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: Theme.dp(4)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon
                    size: Theme.dp(14)
                    color: Theme.subtext
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("labelSmall")
                    font.weight: Theme.typeWeight("labelSmall")
                    color: Theme.subtext
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

        Rectangle { // часы: клик → панель на вкладке «управление»
            id: clockPill
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clockText.implicitWidth + Theme.dp(20)
            implicitHeight: Theme.dp(30)
            radius: Theme.radiusPill
            color: Theme.bgOpaque
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)
            scale: clockArea.pressed ? 0.98 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(120)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Rectangle { // hover/нажатие — state layer
                anchors.fill: parent
                radius: parent.radius
                color: Theme.text
                opacity: clockArea.pressed ? Theme.statePressed : (clockArea.containsMouse ? Theme.stateHover : 0)

                Behavior on opacity { NumberAnimation { duration: Theme.ms(120) } }
            }

            Text {
                id: clockText
                anchors.centerIn: parent
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("titleSmall")
                font.weight: Theme.typeWeight("titleSmall")
                color: Theme.text
                text: Qt.formatDateTime(holder.now, "HH:mm")
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

    // ── OSD: одна пилюля ──────────────────────────────────────────────
    Rectangle {
        id: osdPill
        visible: holder.mode === "osd"
        anchors.centerIn: parent
        implicitWidth: osdRow.implicitWidth + Theme.dp(20)
        implicitHeight: Theme.dp(30)
        radius: Theme.radiusPill
        color: Theme.bgOpaque
        border.width: 1
        border.color: Theme.a(Theme.outline, 0.25)

        OsdRow {
            id: osdRow
            anchors.centerIn: parent
            kind: Osd.kind
            value: Osd.value
            muted: Osd.muted
        }
    }

    // ── Уведомление: одна пилюля ──────────────────────────────────────
    Rectangle {
        id: notifPill
        visible: holder.mode === "notif"
        anchors.centerIn: parent
        implicitWidth: notifRow.implicitWidth + Theme.dp(20)
        implicitHeight: Theme.dp(30)
        radius: Theme.radiusPill
        color: Theme.bgOpaque
        border.width: 1
        border.color: Theme.a(Theme.outline, 0.25)

        NotifToastRow {
            id: notifRow
            anchors.centerIn: parent
            current: Notif.current
        }
    }
}
