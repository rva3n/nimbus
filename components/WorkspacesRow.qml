pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../ui"

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
            readonly property bool hovered: area.containsMouse
            // активный — ink на accentContainer, занятый — subtext, пустой — outline
            readonly property color ink: active ? Theme.fgAccentContainer
                                        : occupied ? Theme.subtext : Theme.outline

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

            height: Theme.dp(22)
            // Lucid-ячейка: активная — rounded-rect (rad 10) accentContainer,
            // занятая — тихая плитка bgTrack, пустая — точка без фона.
            width: (wsPill.hasIcons ? content.implicitWidth + Theme.dp(12) : Theme.dp(12))
                 + (wsPill.active ? Theme.dp(6) : 0)
            // ховер слегка подрастает, нажатие проседает
            scale: area.pressed ? 0.94 : (wsPill.hovered ? 1.08 : 1)

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastEffects
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveFastSpatial
                }
            }

            Rectangle { // фон-плитка + StateLayer
                id: bg
                anchors.fill: parent
                radius: wsPill.active ? Theme.rad(10) : Theme.radiusPill
                color: wsPill.active ? Theme.accentContainer
                     : (wsPill.occupied ? Theme.alpha(Theme.bgTrack, 0.7) : "transparent")

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durFastEffects
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durFastEffects
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveFastSpatial
                    }
                }

                StateLayer {
                    id: area
                    radius: bg.radius
                    tint: wsPill.active ? Theme.fgAccentContainer : Theme.text
                    onClicked: if (wsPill.wsData)
                        Quickshell.execDetached(["umbriel", "msg", "workspace-switch:" + wsPill.wsData.index])
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
                            duration: Theme.durFastEffects
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveFastSpatial
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
                        width: Theme.dp(14)
                        height: Theme.dp(14)

                        Rectangle { // приложение без иконки — точка
                            visible: appIcon.iconPath === ""
                            anchors.centerIn: parent
                            width: Theme.dp(6)
                            height: Theme.dp(6)
                            radius: Theme.radiusPill
                            color: wsPill.ink
                        }

                        AppIcon {
                            anchors.fill: parent
                            visible: appIcon.iconPath !== ""
                            source: appIcon.iconPath
                            size: 14
                        }
                    }
                }
            }
        }
    }
}
