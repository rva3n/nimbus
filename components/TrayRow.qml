pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../core"
import "../ui"

// Системный трей (SNI) в idle-капсуле. Сам по себе — маленькая пилюля-капсула
// (как clockChip): внутри стопка перекрывающихся иконок (до 6) + «+N». Клик по
// капсуле открывает список всех приложений трея в отдельном слое-shell окне:
// ЛКМ — activate() (onlyMenu → контекстное меню), ПКМ — меню приложения,
// СКМ — secondaryActivate(), колесо — scroll(). Меню рисуем сами (QsMenuOpener)
// в том же overlay-окне: нативный QsMenuAnchor требует `pragma UseQApplication`
// в корневом QML, которого здесь нет. Passive-элементы скрыты.
Item {
    id: trayRow

    // Пассивные (status === Status.Passive) не показываем — это фоновые SNI.
    readonly property var allItems: SystemTray.items ? SystemTray.items.values : []
    readonly property var items: trayRow.allItems.filter((it) => it.status !== Status.Passive)
    readonly property int shownCount: Math.min(6, trayRow.items.length)
    readonly property int extraCount: Math.max(0, trayRow.items.length - 6)

    // открытое меню приложения: элемент + точка привязки в координатах окна
    property var menuItem: null
    property real menuX: 0
    property real menuY: 0

    // открытый список: позиция карточки в координатах окна + клавиатурный курсор
    property bool listOpen: false
    property real listX: 0
    property real listY: 0
    property int listIndex: 0

    // Внимание: нельзя опираться на capsule.visible — visible у Item наследуется
    // от предка (Loader), а Loader.visible зависит от этой же implicitWidth.
    // Считаем по длине списка, чтобы не вышла циклическая зависимость.
    implicitWidth: trayRow.items.length > 0 ? capsule.implicitWidth : 0
    implicitHeight: trayRow.items.length > 0 ? capsule.implicitHeight : 0

    // ── API ────────────────────────────────────────────────────────────
    function closeMenu() { trayRow.menuItem = null; }
    function closeList() { trayRow.listOpen = false; trayRow.listIndex = 0; }
    function closeAll() { trayRow.closeList(); trayRow.closeMenu(); }

    function openList() {
        if (trayRow.items.length === 0)
            return;
        const p = capsule.mapToItem(null, 0, capsule.height + Theme.dp(4));
        trayRow.listX = p.x;
        trayRow.listY = p.y;
        trayRow.listIndex = 0;
        trayRow.listOpen = true;
    }

    function moveSelection(delta) {
        const n = trayRow.items.length;
        if (n === 0)
            return;
        trayRow.listIndex = (trayRow.listIndex + delta + n) % n;
        // прокрутить Flickable так, чтобы выбранная строка была видна
        const rowH = Theme.dp(30);
        const top = trayRow.listIndex * rowH;
        const viewH = listFlick.height;
        if (listFlick.contentY > top)
            listFlick.contentY = top;
        else if (listFlick.contentY + viewH < top + rowH)
            listFlick.contentY = Math.min(top + rowH - viewH,
                                          Math.max(0, listFlick.contentHeight - viewH));
    }

    // открыть меню приложения около точки (x, y) в координатах overlay-окна
    function openMenuFor(item, x, y) {
        if (!item || !item.menu)
            return;
        trayRow.menuItem = item;
        trayRow.menuX = x;
        trayRow.menuY = y;
    }

    // ЛКМ/Enter по элементу: onlyMenu → меню, иначе activate() и закрыть список
    function activateItem(item) {
        if (!item)
            return;
        if (item.onlyMenu) {
            const p = capsule.mapToItem(null, 0, capsule.height + Theme.dp(4));
            trayRow.openMenuFor(item, p.x, p.y);
        } else {
            item.activate();
            trayRow.closeList();
        }
    }

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

    // ── Капсула: стопка иконок + «+N» ───────────────────────────────────
    Rectangle {
        id: capsule
        anchors.centerIn: parent
        visible: trayRow.items.length > 0
        implicitWidth: capsuleRow.implicitWidth + Theme.dp(14)
        implicitHeight: Theme.dp(22)
        radius: Theme.radiusPill
        // фон как у clockChip: accentContainer + state layer композитом, альфа 0.5
        color: Theme.alpha(Theme.layer(Theme.accentContainer, Theme.fgAccentContainer,
                           capsuleArea.pressed ? Theme.statePressed
                                               : (capsuleArea.containsMouse ? Theme.stateHover : 0)), 0.5)
        scale: capsuleArea.pressed ? 0.97 : 1

        Behavior on color { ColorAnimation { duration: Theme.ms(120) } }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }

        Row {
            id: capsuleRow
            anchors.centerIn: parent
            spacing: Theme.dp(3)

            // стопка перекрывающихся иконок: слот 18dp, шаг 9dp
            Item {
                id: stack
                anchors.verticalCenter: parent.verticalCenter
                width: trayRow.shownCount > 0
                    ? Theme.dp(18) + (trayRow.shownCount - 1) * Theme.dp(9) : 0
                height: Theme.dp(18)

                Repeater {
                    model: trayRow.items.slice(0, 6)

                    delegate: Item {
                        id: slot
                        required property var modelData
                        required property int index

                        x: index * Theme.dp(9)
                        width: Theme.dp(18)
                        height: Theme.dp(18)
                        z: index

                        // круг цвета капсулы — отделяет иконки друг от друга
                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.dp(18)
                            height: Theme.dp(18)
                            radius: width / 2
                            color: Theme.alpha(Theme.accentContainer, 0.95)
                        }

                        Image {
                            anchors.centerIn: parent
                            width: Theme.dp(15)
                            height: Theme.dp(15)
                            source: trayRow.resolveIconSource(slot.modelData.icon)
                            sourceSize.width: 30
                            sourceSize.height: 30
                            smooth: true
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }

            Text { // «+N» — сколько иконок не поместилось в стопку
                visible: trayRow.extraCount > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "+" + trayRow.extraCount
                color: Theme.fgAccentContainer
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelMedium")
                font.weight: Theme.typeWeight("labelMedium")
            }
        }

        MouseArea {
            id: capsuleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: trayRow.openList()
        }
    }

    // ── Overlay: список + меню приложения во весь экран ────────────────
    PanelWindow {
        id: overlay

        readonly property bool anyOpen: trayRow.listOpen || trayRow.menuItem !== null

        visible: anyOpen
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nimbus-tray-overlay"
        WlrLayershell.keyboardFocus: anyOpen
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onVisibleChanged: {
            if (visible)
                keyCatcher.forceActiveFocus();
        }

        QsMenuOpener {
            id: menuOpener
            menu: trayRow.menuItem ? trayRow.menuItem.menu : null
        }

        // клик мимо карточек закрывает всё
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: trayRow.closeAll()
            onWheel: (wheel) => {
                wheel.accepted = true;
            }
        }

        // ── список всех приложений трея ────────────────────────────────
        Rectangle {
            id: listCard

            readonly property real wanted: listColumn.implicitHeight + Theme.dp(10)
            readonly property int cardW: Theme.dp(280)

            visible: trayRow.listOpen
            width: cardW
            height: Math.min(wanted, overlay.height - Theme.dp(80))
            // рядом с капсулой, с зажимом к краям экрана
            x: Math.max(Theme.dp(8), Math.min(trayRow.listX, overlay.width - cardW - Theme.dp(8)))
            y: Math.max(Theme.dp(8), Math.min(trayRow.listY, overlay.height - height - Theme.dp(8)))
            radius: Theme.radiusSm
            color: Theme.bg
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)
            clip: true

            MouseArea { // клик по фону карточки не закрывает список
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onWheel: (wheel) => {
                    wheel.accepted = true;
                }
            }

            Flickable {
                id: listFlick
                anchors.fill: parent
                anchors.margins: Theme.dp(5)
                contentWidth: width
                contentHeight: listColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: listColumn
                    width: parent.width

                    Repeater {
                        id: listRepeater
                        model: trayRow.items

                        delegate: Item {
                            id: listRow
                            required property var modelData
                            required property int index

                            readonly property bool selected: listRow.index === trayRow.listIndex
                            readonly property bool hovered: listArea.containsMouse

                            width: listColumn.width
                            height: Theme.dp(30)

                            Rectangle { // подложка hover/клавиатурного курсора
                                anchors.fill: parent
                                radius: Theme.radiusXs
                                color: Theme.text
                                opacity: (listRow.hovered || (listRow.selected && trayRow.listOpen))
                                    ? Theme.stateHover : 0
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.dp(8)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.dp(18)
                                height: Theme.dp(18)
                                source: trayRow.resolveIconSource(listRow.modelData.icon)
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
                                text: (listRow.modelData.tooltipTitle
                                       || listRow.modelData.title
                                       || listRow.modelData.id || "?")
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyMedium")
                                font.weight: Theme.typeWeight("bodyMedium")
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: listArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        trayRow.listIndex = listRow.index;
                                }

                                onClicked: (mouse) => {
                                    const item = listRow.modelData;
                                    if (mouse.button === Qt.RightButton) {
                                        const p = listArea.mapToItem(null, mouse.x, mouse.y);
                                        trayRow.openMenuFor(item, p.x, p.y);
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        item.secondaryActivate();
                                    } else {
                                        trayRow.activateItem(item);
                                    }
                                }

                                onWheel: (wheel) => {
                                    listRow.modelData.scroll(wheel.angleDelta.y, false);
                                    wheel.accepted = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── меню приложения ────────────────────────────────────────────
        Rectangle {
            id: menuCard

            readonly property real wanted: entryCol.implicitHeight + Theme.dp(10)
            readonly property int cardW: Theme.dp(210)

            visible: trayRow.menuItem !== null
            width: cardW
            height: Math.min(menuCard.wanted, overlay.height - Theme.dp(80))
            // держим на экране у края
            x: Math.max(Theme.dp(8), Math.min(trayRow.menuX, overlay.width - cardW - Theme.dp(8)))
            y: Math.max(Theme.dp(8), Math.min(trayRow.menuY, overlay.height - height - Theme.dp(8)))
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
                                    trayRow.closeMenu();
                                }
                            }
                        }
                    }
                }
            }
        }

        // клавиатура: список — ↑/↓/Enter, Esc закрывает верхний слой
        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: overlay.anyOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    if (trayRow.menuItem !== null)
                        trayRow.closeMenu();
                    else
                        trayRow.closeList();
                    event.accepted = true;
                } else if (trayRow.listOpen && trayRow.menuItem === null) {
                    if (event.key === Qt.Key_Down) {
                        trayRow.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        trayRow.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        trayRow.activateItem(trayRow.items[trayRow.listIndex]);
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
