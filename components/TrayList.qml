pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../core"
import "../ui"

// Список системного трея как вид острова (не отдельная карточка): живёт в
// той же капсуле под шапкой, растёт вместе с ней, фон/радиус/тень даёт Island.
// Строки: иконка 18 + имя (tooltipTitle || title || id). ЛКМ — activate()
// (onlyMenu → меню), СКМ — secondaryActivate(), колесо — scroll(), ПКМ — меню
// приложения. Меню рисуем сами (QsMenuOpener) в отдельном overlay-окне — оно
// может висеть поверх; жалоба была на список, а не на меню.
Item {
    id: trayList

    property var shell: null
    property var win: null

    readonly property var items: SystemTray.items
        ? SystemTray.items.values.filter((it) => it.status !== Status.Passive) : []

    // открытое меню приложения: элемент + точка привязки в координатах экрана
    property var menuItem: null
    property real menuX: 0
    property real menuY: 0
    // клавиатурный курсор
    property int sel: 0

    // размер берём у содержимого: Island/Loader кладут нас по implicitHeight
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    focus: true

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

    function closeMenu() { trayList.menuItem = null; }

    function openMenuFor(item, x, y) {
        if (!item || !item.menu)
            return;
        trayList.menuItem = item;
        trayList.menuX = x;
        trayList.menuY = y;
    }

    function moveSel(delta) {
        const n = trayList.items.length;
        if (n === 0)
            return;
        trayList.sel = (trayList.sel + delta + n) % n;
    }

    // ЛКМ/Enter: onlyMenu → меню, иначе activate() и закрыть остров
    function activateItem(item) {
        if (!item)
            return;
        if (item.onlyMenu) {
            const p = trayList.mapToItem(null, 0, 0);
            trayList.openMenuFor(item, p.x + Theme.dp(40), p.y + Theme.dp(36));
        } else {
            item.activate();
            if (trayList.shell)
                trayList.shell.closeOverlays();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (trayList.menuItem !== null)
                trayList.closeMenu();
            else if (trayList.shell)
                trayList.shell.closeOverlays();
            event.accepted = true;
        } else if (trayList.menuItem === null) {
            if (event.key === Qt.Key_Down) {
                trayList.moveSel(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                trayList.moveSel(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                trayList.activateItem(trayList.items[trayList.sel]);
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.dp(2)

        Text { // пустой трей
            visible: trayList.items.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(18)
            Layout.bottomMargin: Theme.dp(18)
            horizontalAlignment: Text.AlignHCenter
            text: "Нет приложений в трее"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }

        Repeater {
            model: trayList.items

            delegate: Item {
                id: row
                required property var modelData
                required property int index

                readonly property bool selected: row.index === trayList.sel

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dp(30)

                Rectangle { // подложка hover/клавиатурного курсора
                    anchors.fill: parent
                    radius: Theme.radiusXs
                    color: Theme.text
                    opacity: (rowArea.containsMouse || row.selected) ? Theme.stateHover : 0

                    Behavior on opacity { NumberAnimation { duration: Theme.ms(100) } }
                }

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(18)
                    height: Theme.dp(18)
                    source: trayList.resolveIconSource(row.modelData.icon)
                    sourceSize.width: 36
                    sourceSize.height: 36
                    smooth: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(8) + Theme.dp(18) + Theme.dp(10)
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: (row.modelData.tooltipTitle || row.modelData.title || row.modelData.id || "?")
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodyMedium")
                    font.weight: Theme.typeWeight("bodyMedium")
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onContainsMouseChanged: {
                        if (containsMouse)
                            trayList.sel = row.index;
                    }

                    onClicked: (mouse) => {
                        const item = row.modelData;
                        if (mouse.button === Qt.RightButton) {
                            const p = rowArea.mapToItem(null, mouse.x, mouse.y);
                            trayList.openMenuFor(item, p.x, p.y);
                        } else if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else {
                            trayList.activateItem(item);
                        }
                    }

                    onWheel: (wheel) => {
                        row.modelData.scroll(wheel.angleDelta.y, false);
                        wheel.accepted = true;
                    }
                }
            }
        }
    }

    // ── меню приложения: своё overlay-окно, точка привязки задаётся ──────
    PanelWindow {
        id: trayMenu

        visible: trayList.menuItem !== null
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nimbus-tray-menu"
        WlrLayershell.keyboardFocus: trayList.menuItem !== null
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onVisibleChanged: {
            if (visible)
                keyCatcher.forceActiveFocus();
        }

        QsMenuOpener {
            id: menuOpener
            menu: trayList.menuItem ? trayList.menuItem.menu : null
        }

        // клик мимо карточки закрывает меню
        MouseArea {
            anchors.fill: parent
            onClicked: trayList.closeMenu()
        }

        Rectangle {
            id: menuCard

            readonly property real wanted: entryCol.implicitHeight + Theme.dp(10)
            readonly property int cardW: Theme.dp(210)

            width: cardW
            height: Math.min(menuCard.wanted, trayMenu.height - Theme.dp(80))
            // держим на экране у края
            x: Math.max(Theme.dp(8), Math.min(trayList.menuX, trayMenu.width - cardW - Theme.dp(8)))
            y: Math.max(Theme.dp(8), Math.min(trayList.menuY, trayMenu.height - height - Theme.dp(8)))
            radius: Theme.radiusSm
            color: Theme.bg
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)
            clip: true

            MouseArea { // клик по фону меню не закрывает его
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onWheel: (wheel) => {
                    wheel.accepted = true;
                }
            }

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
                                    trayList.closeMenu();
                                }
                            }
                        }
                    }
                }
            }
        }

        // клавиатура: Escape закрывает меню
        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: trayList.menuItem !== null
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    trayList.closeMenu();
                    event.accepted = true;
                }
            }
        }
    }
}
