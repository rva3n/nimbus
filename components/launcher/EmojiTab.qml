pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Вкладка «Эмодзи»: под-вкладки «Эмодзи / Каомодзи», поиск по имени и ключевым
// словам, сетка с прокруткой. Активация — wl-copy и, если есть wtype, вставка
// в активное окно; после этого оверлеи закрываются.
ColumnLayout {
    id: tab

    property string query: ""
    property int sel: 0
    property var shell: null

    signal hovered(int index)
    // смена под-вкладки: лончер очищает общий поиск
    signal searchReset()

    property string mode: "emoji"    // emoji | kaomoji
    property var emojiAll: []
    property var kaomojiAll: []
    property bool emojiReady: false
    property bool kaomojiReady: false
    property bool haveWtype: false

    readonly property var results: tab.filterList(tab.mode === "emoji" ? tab.emojiAll : tab.kaomojiAll)
    readonly property bool ready: tab.mode === "emoji" ? tab.emojiReady : tab.kaomojiReady
    readonly property int count: tab.results.length

    spacing: Theme.dp(4)

    // экранирование одинарных кавычек для sh
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // поиск по n и k, регистронезависимо
    function filterList(list) {
        const q = tab.query.trim().toLowerCase();
        if (q === "") return list;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const it = list[i];
            if (((it.n || "") + " " + (it.k || "")).toLowerCase().indexOf(q) !== -1) out.push(it);
        }
        return out;
    }

    function setMode(m) {
        if (tab.mode === m) return;
        tab.mode = m;
        tab.searchReset();
    }

    function parseEmoji(txt) {
        try {
            tab.emojiAll = JSON.parse(txt).emoji || [];
        } catch (e) {
            tab.emojiAll = [];
        }
        tab.emojiReady = true;
    }
    function parseKaomoji(txt) {
        try {
            tab.kaomojiAll = JSON.parse(txt).kaomoji || [];
        } catch (e) {
            tab.kaomojiAll = [];
        }
        tab.kaomojiReady = true;
    }

    // копирование и опциональная вставка в активное окно
    function pick(text) {
        const q = tab.shq(text);
        // payload передаём позиционным аргументом ($1): так безопасны $, `,
        // кавычки и бэкслеши, которые встречаются в каомодзи
        let cmd = "wl-copy " + q;
        if (tab.haveWtype)
            cmd += "; setsid -f sh -c 'sleep 0.25; wtype \"$1\"' sh " + q;
        Quickshell.execDetached(["sh", "-c", cmd]);
        if (tab.shell) tab.shell.closeOverlays();
    }

    function activate(index) {
        const it = tab.results[index];
        if (it) tab.pick(it.e);
    }

    onSelChanged: if (grid.count > 0) grid.positionViewAtIndex(Math.max(0, Math.min(grid.count - 1, tab.sel)), GridView.Contain)

    // ── под-вкладки + счётчик ─────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(8)

        Chip {
            label: "Эмодзи"
            selected: tab.mode === "emoji"
            onClicked: tab.setMode("emoji")
        }
        Chip {
            label: "Каомодзи"
            selected: tab.mode === "kaomoji"
            onClicked: tab.setMode("kaomoji")
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: tab.count
            color: Theme.subtextDim
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }
    }

    // ── сетка ─────────────────────────────────────────────────────────
    GridView {
        id: grid

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.dp(360)
        clip: true
        cellWidth: tab.mode === "emoji" ? Theme.dp(40) : Theme.dp(112)
        cellHeight: tab.mode === "emoji" ? Theme.dp(40) : Theme.dp(34)
        model: tab.results
        boundsBehavior: Flickable.StopAtBounds

        delegate: EmojiCell {
            width: grid.cellWidth
            height: grid.cellHeight
            kao: tab.mode === "kaomoji"
            selected: tab.sel === index
            onHovered: (i) => tab.hovered(i)
            onActivated: (i) => tab.activate(i)
        }

        Text { // статус загрузки/пустоты
            anchors.centerIn: parent
            visible: grid.count === 0
            text: !tab.ready ? "Загрузка…"
                : tab.query.trim() !== "" ? "Ничего не найдено"
                : "Нет данных"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }
    }

    FileView { // ~/nimbus/assets/emoji.json
        id: emojiFile
        path: Quickshell.env("HOME") + "/nimbus/assets/emoji.json"
        watchChanges: false
        onLoaded: tab.parseEmoji(emojiFile.text())
        onLoadFailed: tab.emojiReady = true
    }

    FileView { // ~/nimbus/assets/kaomoji.json
        id: kaomojiFile
        path: Quickshell.env("HOME") + "/nimbus/assets/kaomoji.json"
        watchChanges: false
        onLoaded: tab.parseKaomoji(kaomojiFile.text())
        onLoadFailed: tab.kaomojiReady = true
    }

    Process { // есть ли wtype в PATH
        id: wtypeCheck
        command: ["sh", "-c", "command -v wtype >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => tab.haveWtype = exitCode === 0
    }

    // ── ячейка сетки: круг для эмодзи, скругление для каомодзи ────────
    component EmojiCell: Item {
        id: cell

        required property var modelData
        required property int index

        property bool kao: false
        property bool selected: false

        signal hovered(int index)
        signal activated(int index)

        Rectangle { // ховер-подсветка / выбранное
            anchors.centerIn: parent
            width: cell.kao ? parent.width - Theme.dp(4)
                            : Math.min(parent.width, parent.height) - Theme.dp(4)
            height: cell.kao ? parent.height - Theme.dp(2) : width
            radius: cell.kao ? Theme.radiusSm : width / 2
            color: cell.selected ? Theme.accentContainer : Theme.text
            opacity: cell.selected ? 1 : (cellArea.containsMouse ? Theme.stateHover : 0)
            border.width: cell.selected ? 1 : 0
            border.color: Theme.accentBorder

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Theme.easeStandard
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - Theme.dp(6)
            text: cell.modelData ? cell.modelData.e : ""
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: cell.selected ? Theme.fgAccentContainer : Theme.text
            // эмодзи рисуем системным шрифтом (Roboto их не содержит)
            font.family: cell.kao ? Theme.textFont : ""
            font.pixelSize: cell.kao ? Theme.fs(13) : Theme.dp(24)
        }

        MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: cell.hovered(cell.index)
            onClicked: cell.activated(cell.index)
        }
    }
}
