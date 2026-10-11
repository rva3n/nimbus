import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Переключатель окон (аналог Alt+Tab). Оверлей во весь экран (Overlay), по
// центру — карточка со списком окон Umbriel. Логика:
//   summon(1)  — открыть и выбрать следующее окно после активного
//   summon(-1) — открыть и выбрать предыдущее
//   summon(dir) при открытом — шаг по списку на dir с закольцовкой
//   close()    — закрыть
// Переключение одиночным вызовом IPC ради клавиши Alt+Tab (циклично), но
// подтверждение — Enter/клик; активация через `umbriel msg window-focus:<id>`.
PanelWindow {
    id: switcher

    property bool open: false
    property int _sel: 0

    // порядок — как отдаёт Umbriel, без сортировки
    readonly property var items: Umbriel.windows

    // ── icon index: app_id (lowercase) → имя иконки ───────────────────
    // тот же приём, что и в WorkspacesRow: точное совпадение по id, затем
    // startupClass; затем Quickshell.iconPath(name, true).
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
        const ix = switcher.iconIndex;
        const name = ix.byId[k] || ix.byClass[k] || "";
        return name !== "" ? Quickshell.iconPath(name, true) : "";
    }

    // ── навигация ─────────────────────────────────────────────────────
    function _wrapIndex(i) {
        const n = switcher.items.length;
        if (n <= 0) return 0;
        return ((i % n) + n) % n;
    }

    function _step(dir) {
        if (switcher.items.length === 0) return;
        switcher._sel = switcher._wrapIndex(switcher._sel + dir);
    }

    function summon(dir) {
        if (!switcher.open) {
            switcher.open = true;
            const n = switcher.items.length;
            if (n === 0) { switcher._sel = 0; return; }
            // активный в списке; если активного нет — с -1 для dir>0
            let base = -1;
            for (let i = 0; i < n; i++) {
                if (switcher.items[i] && switcher.items[i].active) { base = i; break; }
            }
            if (base < 0) base = dir < 0 ? 0 : -1;
            switcher._sel = switcher._wrapIndex(base + dir);
        } else {
            switcher._step(dir);
        }
    }

    function close() {
        switcher.open = false;
    }

    function activate() {
        const it = switcher.items[switcher._sel];
        const id = it ? it.id : "";
        if (id === undefined || id === null || String(id) === "") {
            switcher.close();
            return;
        }
        Quickshell.execDetached(["umbriel", "msg", "window-focus:" + id]);
        switcher.close();
    }

    // список изменился — не выходим за границы
    onItemsChanged: {
        const n = switcher.items.length;
        if (n === 0) { switcher._sel = 0; return; }
        switcher._sel = Math.max(0, Math.min(switcher._sel, n - 1));
    }

    // при открытии — забрать клавиатуру
    onOpenChanged: if (switcher.open) keyCatcher.forceActiveFocus()

    visible: switcher.open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nimbus-switcher"
    WlrLayershell.keyboardFocus: switcher.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ── приглушённый фон и перехват кликов вне карточки ───────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: switcher.close()
        }
    }

    // ── карточка ──────────────────────────────────────────────────────
    Card {
        id: dialog
        anchors.centerIn: parent
        width: Theme.dp(560)
        pad: Theme.dp(16)

        readonly property real rowH: Theme.dp(44)

        Text {
            Layout.fillWidth: true
            text: "Переключение окон"
            color: Theme.subtextDim
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelLarge")
            font.weight: Theme.typeWeight("labelLarge")
            elide: Text.ElideRight
        }

        ListView {
            id: winList

            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(6)
            implicitHeight: Math.min(Math.max(1, switcher.items.length), 8) * dialog.rowH
            height: implicitHeight
            clip: true
            spacing: 0
            model: switcher.items
            currentIndex: switcher._sel
            onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < count)
                positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
                id: rowItem

                required property var modelData
                required property int index

                readonly property bool selected: index === switcher._sel
                readonly property string title: (modelData && modelData.title) ? modelData.title : ""
                readonly property string appId: (modelData && modelData.app_id) ? modelData.app_id : ""
                readonly property string ws: (modelData && modelData.workspace) ? String(modelData.workspace) : ""
                readonly property string iconPath: switcher.iconFor(appId)

                width: winList.width
                height: dialog.rowH

                Rectangle {
                    id: row

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: dialog.rowH - Theme.dp(4)
                    radius: Theme.radiusMd
                    color: rowItem.selected ? Theme.accentContainer
                                            : (rowHover.containsMouse ? Theme.bgHover : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Theme.durQuick }
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            switcher._sel = rowItem.index;
                            switcher.activate();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(10)
                        anchors.rightMargin: Theme.dp(10)
                        spacing: Theme.dp(12)

                        // иконка приложения (или точка, если её нет)
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Theme.dp(28)
                            Layout.preferredHeight: Theme.dp(28)

                            Rectangle {
                                visible: rowItem.iconPath === ""
                                anchors.centerIn: parent
                                width: Theme.dp(10)
                                height: Theme.dp(10)
                                radius: Theme.radiusPill
                                color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtext
                            }

                            AppIcon {
                                anchors.fill: parent
                                visible: rowItem.iconPath !== ""
                                source: rowItem.iconPath
                                size: 28
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: rowItem.title !== "" ? rowItem.title : rowItem.appId
                                color: rowItem.selected ? Theme.fgAccentContainer : Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyLarge")
                                font.weight: Theme.typeWeight("titleSmall")
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: rowItem.appId
                                color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtextDim
                                opacity: rowItem.selected ? 0.75 : 1
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                                elide: Text.ElideRight
                            }
                        }

                        // бейдж воркспейса — сырая строка "DP-1:8"
                        Rectangle {
                            visible: rowItem.ws !== ""
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: wsLabel.implicitWidth + Theme.dp(12)
                            implicitHeight: Theme.dp(20)
                            radius: Theme.radiusSm
                            color: rowItem.selected ? Theme.alpha(Theme.fgAccentContainer, 0.12)
                                                    : Theme.bgTrack

                            Text {
                                id: wsLabel
                                anchors.centerIn: parent
                                text: rowItem.ws
                                color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtextDim
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                            }
                        }
                    }
                }
            }

            Text { // пусто
                anchors.centerIn: parent
                visible: winList.count === 0
                text: "Нет окон"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium")
            }
        }
    }

    // ── клавиатура ────────────────────────────────────────────────────
    // Фокусируемый прозрачный слой поверх окна; клавиши приходят только при
    // open (mirror PolkitPrompt: OnDemand focus + forceActiveFocus).
    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: switcher.open

        Keys.onPressed: (event) => {
            if (!switcher.open) return;
            if (event.key === Qt.Key_Tab) {
                switcher._step((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                switcher._step(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                switcher._step(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                switcher._step(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                switcher.activate();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                switcher.close();
                event.accepted = true;
            }
        }
        Keys.onReleased: (event) => {
            if (!switcher.open) return;
            // по-виндовому: отпустил Alt — сразу переключаемся на выбранное окно
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                switcher.activate();
                event.accepted = true;
            }
        }
    }
}
