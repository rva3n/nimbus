import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"
import "launcher"

// Единая поверхность лончера: вкладки «Приложения / Буфер / Эмодзи / Пакеты»,
// общий поиск и карточка с содержимым активной вкладки. Клавиатура: ↑/↓, Enter, Esc.
ColumnLayout {
    id: launcher

    property bool active: false
    property var shell: null
    // внешняя вкладка (shell.launcherTab): apps | clipboard | emoji | packages
    property string tab: "apps"

    // внутренняя вкладка живёт отдельно, чтобы клик по чипу не терялся
    property string currentTab: "apps"
    property string query: ""
    property int sel: 0

    readonly property var activeTab: launcher.currentTab === "apps" ? appsTab
                                   : launcher.currentTab === "clipboard" ? clipTab
                                   : launcher.currentTab === "packages" ? pkgTab : emojiTab
    readonly property int count: launcher.activeTab ? launcher.activeTab.count : 0

    visible: active
    Layout.fillWidth: true
    spacing: Theme.dp(14)

    // сброс поиска и выделения
    function resetSearch() {
        launcher.query = "";
        launcher.sel = 0;
        searchField.text = "";
    }
    // применить вкладку (валидные: apps | clipboard | emoji | packages)
    function applyTab(t) {
        const v = (t === "clipboard" || t === "emoji" || t === "packages") ? t : "apps";
        if (launcher.currentTab === v) return;
        launcher.currentTab = v;
        launcher.resetSearch();
    }
    function switchTab(t) {
        launcher.applyTab(t);
        if (launcher.shell) launcher.shell.launcherTab = t;
    }
    function setSel(i) {
        launcher.sel = Math.max(0, Math.min(i, launcher.count - 1));
    }
    function activateSel() {
        if (launcher.activeTab && launcher.count > 0) launcher.activeTab.activate(launcher.sel);
    }

    // при открытии — вкладка из shell.launcherTab (IPC: launcher/clipboard/emoji/packages)
    onActiveChanged: if (launcher.active) launcher.applyTab(launcher.tab)
    onTabChanged: if (launcher.active) launcher.applyTab(launcher.tab)
    onCountChanged: launcher.setSel(launcher.sel) // clamp после смены вкладки/фильтра
    onQueryChanged: launcher.sel = 0

    // ── вкладки; справа — фильтр скрытых (только в приложениях) ───────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(6)

        Chip {
            label: "Приложения"; icon: "apps"
            selected: launcher.currentTab === "apps"
            onClicked: launcher.switchTab("apps")
        }
        Chip {
            label: "Буфер"; icon: "content_paste"
            selected: launcher.currentTab === "clipboard"
            onClicked: launcher.switchTab("clipboard")
        }
        Chip {
            label: "Эмодзи"; icon: "mood"
            selected: launcher.currentTab === "emoji"
            onClicked: launcher.switchTab("emoji")
        }
        Chip {
            label: "Пакеты"; icon: "inventory_2"
            selected: launcher.currentTab === "packages"
            onClicked: launcher.switchTab("packages")
        }

        Item { Layout.fillWidth: true }

        Chip {
            visible: launcher.currentTab === "apps"
            label: "Скрытые (" + Apps.hidden.length + ")"
            icon: "visibility"
            selected: Apps.showHidden
            onClicked: Apps.showHidden = !Apps.showHidden
        }
    }

    // ── поиск: общий для всех вкладок ─────────────────────────────────
    TextField {
        id: searchField

        Layout.fillWidth: true
        focus: launcher.active
        placeholder: launcher.currentTab === "apps" ? "Поиск приложений…"
                   : launcher.currentTab === "clipboard" ? "Поиск в буфере…"
                   : launcher.currentTab === "packages" ? "Поиск пакетов…"
                   : "Поиск эмодзи…"
        onTextChanged: launcher.query = searchField.text
        onAccepted: launcher.activateSel()
        Keys.onEscapePressed: if (launcher.shell) launcher.shell.closeOverlays()
        Keys.onDownPressed: launcher.setSel(launcher.sel + 1)
        Keys.onUpPressed: launcher.setSel(launcher.sel - 1)
    }

    // ── содержимое активной вкладки ───────────────────────────────────
    Card {
        Layout.fillWidth: true

        AppsTab {
            id: appsTab
            visible: launcher.currentTab === "apps"
            Layout.fillWidth: true
            shell: launcher.shell
            query: launcher.query
            sel: launcher.sel
            onHovered: (i) => launcher.setSel(i)
        }

        ClipboardTab {
            id: clipTab
            visible: launcher.currentTab === "clipboard"
            Layout.fillWidth: true
            shell: launcher.shell
            active: launcher.active && launcher.currentTab === "clipboard"
            query: launcher.query
            sel: launcher.sel
            onHovered: (i) => launcher.setSel(i)
        }

        EmojiTab {
            id: emojiTab
            visible: launcher.currentTab === "emoji"
            Layout.fillWidth: true
            shell: launcher.shell
            query: launcher.query
            sel: launcher.sel
            onHovered: (i) => launcher.setSel(i)
            onSearchReset: launcher.resetSearch()
        }

        PackagesTab {
            id: pkgTab
            visible: launcher.currentTab === "packages"
            Layout.fillWidth: true
            shell: launcher.shell
            active: launcher.active && launcher.currentTab === "packages"
            query: launcher.query
            sel: launcher.sel
            onHovered: (i) => launcher.setSel(i)
        }
    }
}
