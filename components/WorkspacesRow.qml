pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"

// Пилюли воркспейсов Umbriel: активный — accentContainer, занятые — до трёх
// иконок приложений, пустые — точка. Модель — по индексу (длина списка),
// а не сам массив: делегаты не пересоздаются, поэтому анимации ширины и
// цвета реально играют.
Row {
    id: wsRow
    property string output: ""
    spacing: Theme.dp(4)

    readonly property var items: Umbriel.workspacesFor(output)

    // app_id (lowercase) → имя иконки: точное совпадение по id, затем startupClass
    readonly property var iconIndex: {
        const byId = {};
        const byClass = {};
        for (const e of DesktopEntries.applications.values) {
            if (!e.icon) continue;
            if (e.id) byId[String(e.id).toLowerCase()] = e.icon;
            if (e.startupClass) byClass[String(e.startupClass).toLowerCase()] = e.icon;
        }
        return { byId: byId, byClass: byClass };
    }

    function iconFor(appId) {
        const k = String(appId || "").toLowerCase();
        if (k === "") return "";
        const ix = wsRow.iconIndex;
        return ix.byId[k] || ix.byClass[k] || "";
    }

    Repeater {
        model: wsRow.items.length

        delegate: Item {
            id: wsPill
            required property int index

            readonly property var wsData: wsRow.items[index] || null
            readonly property bool active: wsData ? wsData.active : false
            readonly property bool occupied: wsData ? wsData.occupied : false
            readonly property color ink: active ? Theme.fgAccentContainer
                                        : occupied ? Theme.subtext : Theme.subtextDim

            // до 3 приложений воркспейса; path — найденная иконка или ""
            readonly property var shownApps: {
                const src = wsData ? Umbriel.appsFor(wsData.id) : [];
                const out = [];
                for (let i = 0; i < src.length && out.length < 3; i++) {
                    const name = wsRow.iconFor(src[i].app_id);
                    out.push({ path: name !== "" ? Quickshell.iconPath(name, true) : "" });
                }
                return out;
            }
            readonly property bool hasIcons: {
                for (let i = 0; i < shownApps.length; i++)
                    if (shownApps[i].path !== "") return true;
                return false;
            }

            height: Theme.dp(20)
            // ровный ритм: пустой слот 8 (+8 активному), занятый — иконки + 4
            // (+8 активному); активность даёт одинаковую прибавку всем
            width: (wsPill.hasIcons ? content.implicitWidth + Theme.dp(4) : Theme.dp(8))
                 + (wsPill.active ? Theme.dp(8) : 0)
            scale: area.pressed ? 0.98 : 1

            Behavior on width {
                NumberAnimation {
                    duration: Theme.ms(160)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.ms(160)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Rectangle { // фон-пилюля: активный — accentContainer
                anchors.fill: parent
                radius: Theme.radiusPill
                color: wsPill.active ? Theme.a(Theme.accentContainer, 0.88) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(160)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveEffects
                    }
                }

                Rectangle { // hover/нажатие — лёгкий state layer
                    anchors.fill: parent
                    radius: parent.radius
                    color: wsPill.active ? Theme.fgAccentContainer : Theme.text
                    opacity: area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0)

                    Behavior on opacity { NumberAnimation { duration: Theme.ms(120) } }
                }
            }

            Row { // содержимое: точка или иконки приложений
                id: content
                anchors.centerIn: parent
                spacing: Theme.dp(3)

                Rectangle { // пустой воркспейс / иконок не нашлось — точка
                    visible: !wsPill.hasIcons
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(6)
                    height: Theme.dp(6)
                    radius: Theme.radiusPill
                    color: wsPill.ink

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.ms(160)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveEffects
                        }
                    }
                }

                Repeater {
                    model: wsPill.hasIcons ? wsPill.shownApps.length : 0

                    delegate: Item {
                        id: appIcon
                        required property int index

                        readonly property string iconPath: {
                            const a = wsPill.shownApps[index];
                            return a ? a.path : "";
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(13)
                        height: Theme.dp(13)

                        Rectangle { // приложение без иконки — точка
                            visible: appIcon.iconPath === ""
                            anchors.centerIn: parent
                            width: Theme.dp(6)
                            height: Theme.dp(6)
                            radius: Theme.radiusPill
                            color: wsPill.active ? Theme.fgAccentContainer : Theme.subtext
                        }

                        Image {
                            id: img
                            anchors.fill: parent
                            visible: appIcon.iconPath !== ""
                            source: appIcon.iconPath
                            sourceSize.width: Theme.dp(26)
                            sourceSize.height: Theme.dp(26)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (wsPill.wsData)
                    Quickshell.execDetached(["umbriel", "msg", "workspace-switch:" + wsPill.wsData.index])
            }
        }
    }
}
