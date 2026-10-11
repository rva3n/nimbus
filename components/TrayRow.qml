pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../core"
import "../ui"

// Системный трей (SNI) в idle-капсуле: маленькая пилюля-капсула (как clockChip)
// со стопкой перекрывающихся иконок (до 6) + «+N». Клик открывает вид острова
// «трей» (shell.toggleTray) — список живёт в самой капсуле острова, а не
// отдельной карточкой. Passive-элементы скрыты.
Item {
    id: trayRow

    property var shell: null

    // Пассивные (status === Status.Passive) не показываем — это фоновые SNI.
    readonly property var allItems: SystemTray.items ? SystemTray.items.values : []
    readonly property var items: trayRow.allItems.filter((it) => it.status !== Status.Passive)
    readonly property int shownCount: Math.min(6, trayRow.items.length)
    readonly property int extraCount: Math.max(0, trayRow.items.length - 6)

    // Внимание: нельзя опираться на capsule.visible — visible у Item наследуется
    // от предка (Loader), а Loader.visible зависит от этой же implicitWidth.
    // Считаем по длине списка, чтобы не вышла циклическая зависимость.
    implicitWidth: trayRow.items.length > 0 ? capsule.implicitWidth : 0
    implicitHeight: trayRow.items.length > 0 ? capsule.implicitHeight : 0

    // "image://…", "file://…" и абсолютные пути — как есть; "name?path=/dir" →
    // file:///dir/name; иначе имя без пути → Quickshell.iconPath(name, true).
    function resolveIconSource(raw) {
        if (!raw)
            return "";
        if (raw.startsWith("image://") || raw.startsWith("file://") || raw.startsWith("/"))
            return raw;
        const qIdx = raw.indexOf("?path=");
        if (qIdx !== -1) {
            const name = raw.substring(0, qIdx);
            const dir = raw.substring(qIdx + 6);
            const fileName = name.substring(name.lastIndexOf("/") + 1);
            return "file://" + dir + "/" + fileName;
        }
        return Quickshell.iconPath(raw, true);
    }

    // ── Капсула: нейтральная Lucid-пилюля + StateLayer ─────────────────
    // Иконки приложений — в собственных цветах; верхний круг цвета капсулы
    // отделяет перекрывающиеся иконки.
    Rectangle {
        id: capsule
        anchors.centerIn: parent
        visible: trayRow.items.length > 0
        implicitWidth: capsuleRow.implicitWidth + Theme.dp(16)
        implicitHeight: Theme.dp(24)
        radius: Theme.radiusPill
        color: Theme.bgTile
        scale: capsuleArea.pressed ? 0.97 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastEffects
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }
        }

        StateLayer {
            id: capsuleArea
            radius: parent.radius
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: if (trayRow.shell) trayRow.shell.toggleTray()
        }

        Row {
            id: capsuleRow
            anchors.centerIn: parent
            spacing: Theme.dp(3)

            // стопка перекрывающихся иконок: слот 22dp, шаг 13dp
            Item {
                id: stack
                anchors.verticalCenter: parent.verticalCenter
                width: trayRow.shownCount > 0
                    ? Theme.dp(22) + (trayRow.shownCount - 1) * Theme.dp(13) : 0
                height: Theme.dp(22)

                Repeater {
                    model: trayRow.items.slice(0, 6)

                    delegate: Item {
                        id: slot
                        required property var modelData
                        required property int index

                        x: index * Theme.dp(13)
                        width: Theme.dp(22)
                        height: Theme.dp(22)
                        z: index

                        // круг цвета капсулы — отделяет иконки друг от друга
                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.dp(22)
                            height: Theme.dp(22)
                            radius: width / 2
                            color: Theme.bgTile
                        }

                        Image {
                            anchors.centerIn: parent
                            width: Theme.dp(18)
                            height: Theme.dp(18)
                            source: trayRow.resolveIconSource(slot.modelData.icon)
                            sourceSize.width: 36
                            sourceSize.height: 36
                            smooth: true
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }

            LText { // «+N» — сколько иконок не поместилось в стопку
                visible: trayRow.extraCount > 0
                anchors.verticalCenter: parent.verticalCenter
                role: "labelMedium"
                color: Theme.subtext
                text: "+" + trayRow.extraCount
            }
        }
    }
}
