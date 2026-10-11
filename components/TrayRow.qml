pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../core"
import "../ui"

// Системный трей (SNI) в idle-капсуле: ряд иконок запущенных приложений.
// ЛКМ — activate(), СКМ — secondaryActivate(), колесо — scroll(), ПКМ — меню
// приложения. Меню рисуем сами (QsMenuOpener) в отдельном слое-shell окне
// возле острова: нативный QsMenuAnchor требует `pragma UseQApplication` в
// корневом QML, которого здесь нет. На пустом трее ряд пуст и нулевой ширины —
// раскладка острова не дёргается.
Row {
    id: trayRow

    readonly property var items: SystemTray.items ? SystemTray.items.values : []

    // открытое меню: элемент трея + точка привязки в координатах окна
    property var menuItem: null
    property real menuX: 0
    property real menuY: 0

    spacing: Theme.dp(6)
    visible: iconRepeater.count > 0

    function closeMenu() { trayRow.menuItem = null; }

    // "name?path=/dir" → file:///dir/name; имя иконки без "?path=" — как есть.
    // Тот же разбор, что в lucidbar/SysTray.qml.
    function resolveIconSource(raw) {
        if (!raw)
            return "";
        const qIdx = raw.indexOf("?path=");
        if (qIdx === -1)
            return raw;
        const name = raw.substring(0, qIdx);
        const dir = raw.substring(qIdx + 6);
        const fileName = name.substring(name.lastIndexOf("/") + 1);
        return "file://" + dir + "/" + fileName;
    }

    Repeater {
        id: iconRepeater
        model: trayRow.items

        delegate: Item {
            id: iconSlot
            required property var modelData

            width: Theme.dp(18)
            height: Theme.dp(18)

            Image {
                anchors.fill: parent
                source: trayRow.resolveIconSource(iconSlot.modelData.icon)
                sourceSize.width: 36
                sourceSize.height: 36
                smooth: true
                asynchronous: true
                fillMode: Image.PreserveAspectFit
            }

            Rectangle { // мягкая подложка при наведении
                visible: hoverArea.containsMouse
                anchors.fill: parent
                radius: Theme.radiusSm
                color: Theme.text
                opacity: Theme.stateHover
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: (mouse) => {
                    const item = iconSlot.modelData;
                    if (mouse.button === Qt.RightButton) {
                        if (!item.menu)
                            return;
                        const p = iconSlot.mapToItem(null, 0, iconSlot.height + Theme.dp(4));
                        trayRow.menuItem = item;
                        trayRow.menuX = p.x;
                        trayRow.menuY = p.y;
                    } else if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else {
                        item.activate();
                    }
                }
                onWheel: (wheel) => {
                    iconSlot.modelData.scroll(wheel.angleDelta.y, false);
                    wheel.accepted = true;
                }
            }
        }
    }

    // ── меню приложения: своё слое-shell окно во весь экран ─────────────
    PanelWindow {
        id: trayMenu

        visible: trayRow.menuItem !== null
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nimbus-tray-menu"
        WlrLayershell.keyboardFocus: trayRow.menuItem !== null
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onVisibleChanged: {
            if (visible)
                keyCatcher.forceActiveFocus();
        }

        QsMenuOpener {
            id: menuOpener
            menu: trayRow.menuItem ? trayRow.menuItem.menu : null
        }

        // клик мимо карточки закрывает меню
        MouseArea {
            anchors.fill: parent
            onClicked: trayRow.closeMenu()
        }

        Rectangle {
            id: menuCard

            readonly property real wanted: entryCol.implicitHeight + Theme.dp(10)
            readonly property int cardW: Theme.dp(210)

            width: cardW
            height: Math.min(menuCard.wanted, trayMenu.height - Theme.dp(80))
            // держим на экране у края
            x: Math.max(Theme.dp(8), Math.min(trayRow.menuX, trayMenu.width - cardW - Theme.dp(8)))
            y: Math.min(trayRow.menuY, trayMenu.height - height - Theme.dp(8))
            radius: Theme.radiusSm
            color: Theme.bg
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.dp(5)
                contentWidth: width
                contentHeight: entryCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: entryCol
                    width: parent.width

                    Repeater {
                        model: menuOpener.children

                        delegate: Item {
                            id: entryRow
                            required property var modelData

                            readonly property var entry: entryRow.modelData
                            readonly property bool isSep: entry.isSeparator || entry.text === ""
                            readonly property bool checked: entry.checkState !== Qt.Unchecked

                            width: entryCol.width
                            height: entryRow.isSep ? Theme.dp(7) : Theme.dp(28)

                            Rectangle { // разделитель
                                visible: entryRow.isSep
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Theme.dp(4)
                                height: 1
                                color: Theme.outline
                            }

                            Rectangle { // подложка hover
                                visible: !entryRow.isSep
                                anchors.fill: parent
                                radius: Theme.radiusXs
                                color: Theme.text
                                opacity: (entryArea.containsMouse && entryRow.entry.enabled)
                                    ? Theme.stateHover : 0
                            }

                            Icon { // галочка отмеченного пункта
                                visible: !entryRow.isSep && entryRow.checked
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.dp(6)
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: Theme.dp(14)
                                color: Theme.accent
                            }

                            Text {
                                visible: !entryRow.isSep
                                anchors.left: parent.left
                                anchors.leftMargin: entryRow.checked ? Theme.dp(24) : Theme.dp(10)
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(10)
                                anchors.verticalCenter: parent.verticalCenter
                                text: entryRow.entry.text
                                color: entryRow.entry.enabled ? Theme.text : Theme.subtextDim
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyMedium")
                                font.weight: Theme.typeWeight("bodyMedium")
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: entryArea
                                anchors.fill: parent
                                enabled: !entryRow.isSep && entryRow.entry.enabled
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    entryRow.entry.triggered();
                                    trayRow.closeMenu();
                                }
                            }
                        }
                    }
                }
            }
        }

        // клавиатура: Escape закрывает
        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: trayRow.menuItem !== null
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    trayRow.closeMenu();
                    event.accepted = true;
                }
            }
        }
    }
}
