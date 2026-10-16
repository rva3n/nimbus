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
    property var submenuEntry: null
    property real submenuY: 0

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

    function closeMenu() {
        trayList.menuItem = null;
        trayList.submenuEntry = null;
    }

    function openMenuFor(item, x, y) {
        if (!item || !item.menu)
            return;
        trayList.menuItem = item;
        trayList.submenuEntry = null;
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

        LText { // пустой трей
            visible: trayList.items.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(18)
            Layout.bottomMargin: Theme.dp(18)
            horizontalAlignment: Text.AlignHCenter
            role: "bodyMedium"
            color: Theme.subtext
            text: "Нет приложений в трее"
        }

        Repeater {
            model: trayList.items

            delegate: Item {
                id: row
                required property var modelData
                required property int index

                readonly property bool selected: row.index === trayList.sel

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dp(48)

                Rectangle { // подложка: выбранная — secondaryContainer, ховер — bgHover
                    anchors.fill: parent
                    anchors.margins: Theme.dp(1)
                    radius: Theme.radiusSm
                    color: row.selected ? Theme.secondaryContainer
                         : (rowArea.containsMouse ? Theme.bgHover : "transparent")

                    Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                }

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(22)
                    height: Theme.dp(22)
                    source: trayList.resolveIconSource(row.modelData.icon)
                    sourceSize.width: 44
                    sourceSize.height: 44
                    smooth: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }

                LText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(12) + Theme.dp(22) + Theme.dp(12)
                    anchors.right: parent.right
                    anchors.rightMargin: row.modelData.hasChildren ? Theme.dp(34) : Theme.dp(12)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyMedium"
                    color: row.selected ? Theme.fgSecondaryContainer : Theme.text
                    text: (row.modelData.tooltipTitle || row.modelData.title || row.modelData.id || "?")
                    elide: Text.ElideRight
                }

                Icon {
                    visible: row.modelData.hasChildren
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron_right"
                    size: Theme.dp(16)
                    color: row.selected ? Theme.fgSecondaryContainer : Theme.subtextDim
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
        WlrLayershell.namespace: "oberon-tray-menu"
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

        QsMenuOpener {
            id: submenuOpener
            menu: trayList.submenuEntry
        }

        // клик мимо карточки закрывает меню
        MouseArea {
            anchors.fill: parent
            onClicked: trayList.closeMenu()
        }

        Rectangle {
            id: menuCard

            readonly property real wanted: entryCol.implicitHeight + Theme.dp(12)
            readonly property int cardW: Theme.dp(220)

            width: cardW
            height: Math.min(menuCard.wanted, trayMenu.height - Theme.dp(80))
            // держим на экране у края
            x: Math.max(Theme.dp(8), Math.min(trayList.menuX, trayMenu.width - cardW - Theme.dp(8)))
            y: Math.max(Theme.dp(8), Math.min(trayList.menuY, trayMenu.height - height - Theme.dp(8)))
            // Lucid popup-карточка: размытый surfaceHigh, крупный радиус, без обводки
            radius: Theme.radiusMd
            color: Theme.withBlur(Theme.mHigh)
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
                            height: entryRow.isSep ? Theme.dp(7) : Theme.dp(36)

                            Rectangle { // разделитель
                                visible: entryRow.isSep
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Theme.dp(6)
                                height: 1
                                color: Theme.outline
                            }

                            Rectangle { // подложка hover
                                visible: !entryRow.isSep
                                anchors.fill: parent
                                anchors.margins: Theme.dp(1)
                                radius: Theme.radiusXs
                                color: (entryArea.containsMouse && entryRow.entry.enabled)
                                    ? Theme.bgHover : "transparent"

                                Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                            }

                            Icon { // галочка отмеченного пункта
                                visible: !entryRow.isSep && entryRow.checked
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.dp(8)
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: Theme.dp(16)
                                color: Theme.accent
                            }

                            LText {
                                visible: !entryRow.isSep
                                anchors.left: parent.left
                                anchors.leftMargin: entryRow.checked ? Theme.dp(34) : Theme.dp(12)
                                anchors.right: parent.right
                                anchors.rightMargin: entryRow.entry.hasChildren ? Theme.dp(32) : Theme.dp(12)
                                anchors.verticalCenter: parent.verticalCenter
                                role: "bodyMedium"
                                color: entryRow.entry.enabled ? Theme.text : Theme.subtextDim
                                text: entryRow.entry.text
                                elide: Text.ElideRight
                            }

                            Icon {
                                visible: !entryRow.isSep && entryRow.entry.hasChildren
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(8)
                                anchors.verticalCenter: parent.verticalCenter
                                name: "chevron_right"
                                size: Theme.dp(16)
                                color: entryRow.entry.enabled ? Theme.subtextDim : Theme.outline
                            }

                            MouseArea {
                                id: entryArea
                                anchors.fill: parent
                                enabled: !entryRow.isSep && entryRow.entry.enabled
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (entryRow.entry.hasChildren) {
                                        if (trayList.submenuEntry === entryRow.entry) {
                                            trayList.submenuEntry = null;
                                        } else {
                                            const p = entryArea.mapToItem(null, entryArea.width, entryArea.height / 2);
                                            trayList.submenuEntry = entryRow.entry;
                                            trayList.submenuY = p.y;
                                        }
                                    } else {
                                        entryRow.entry.triggered();
                                        trayList.closeMenu();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Подменю: второй QsMenuOpener открывает дочерние пункты в соседней карточке.
        Rectangle {
            id: submenuCard

            readonly property real wanted: submenuCol.implicitHeight + Theme.dp(12)
            readonly property int cardW: Theme.dp(220)

            visible: trayList.submenuEntry !== null
            width: cardW
            height: Math.min(submenuCard.wanted, trayMenu.height - Theme.dp(16))
            x: menuCard.x + menuCard.width + cardW <= trayMenu.width - Theme.dp(8)
                ? menuCard.x + menuCard.width - Theme.dp(4)
                : Math.max(Theme.dp(8), menuCard.x - cardW + Theme.dp(4))
            y: Math.max(Theme.dp(8), Math.min(trayList.submenuY - height / 2,
                trayMenu.height - height - Theme.dp(8)))
            radius: Theme.radiusMd
            color: Theme.withBlur(Theme.mHigh)
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onWheel: wheel.accepted = true
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.dp(5)
                contentWidth: width
                contentHeight: submenuCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: submenuCol
                    width: parent.width

                    Repeater {
                        model: submenuOpener.children

                        delegate: Item {
                            id: subEntryRow
                            required property var modelData

                            readonly property var entry: subEntryRow.modelData
                            readonly property bool isSep: entry.isSeparator || entry.text === ""
                            readonly property bool checked: entry.checkState !== Qt.Unchecked

                            width: submenuCol.width
                            height: subEntryRow.isSep ? Theme.dp(7) : Theme.dp(36)

                            Rectangle {
                                visible: subEntryRow.isSep
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Theme.dp(6)
                                height: 1
                                color: Theme.outline
                            }

                            Rectangle {
                                visible: !subEntryRow.isSep
                                anchors.fill: parent
                                anchors.margins: Theme.dp(1)
                                radius: Theme.radiusXs
                                color: (subEntryArea.containsMouse && subEntryRow.entry.enabled)
                                    ? Theme.bgHover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                            }

                            Icon {
                                visible: !subEntryRow.isSep && subEntryRow.checked
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.dp(8)
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: Theme.dp(16)
                                color: Theme.accent
                            }

                            LText {
                                visible: !subEntryRow.isSep
                                anchors.left: parent.left
                                anchors.leftMargin: subEntryRow.checked ? Theme.dp(34) : Theme.dp(12)
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(12)
                                anchors.verticalCenter: parent.verticalCenter
                                role: "bodyMedium"
                                color: subEntryRow.entry.enabled ? Theme.text : Theme.subtextDim
                                text: subEntryRow.entry.text
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: subEntryArea
                                anchors.fill: parent
                                enabled: !subEntryRow.isSep && subEntryRow.entry.enabled
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    subEntryRow.entry.triggered();
                                    trayList.closeMenu();
                                }
                            }
                        }
                    }
                }
            }
        }

        // клавиатура: Escape закрывает сперва подменю, затем всё меню
        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: trayList.menuItem !== null
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    if (trayList.submenuEntry !== null)
                        trayList.submenuEntry = null;
                    else
                        trayList.closeMenu();
                    event.accepted = true;
                }
            }
        }
    }
}
