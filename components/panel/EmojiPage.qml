import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"
import ".."

// Страница «Эмодзи»: вкладки «Эмодзи / Каомодзи», поиск по имени и ключевым
// словам, сетка с прокруткой. Клик — wl-copy и (если есть wtype) вставка в
// активное окно, после чего панель закрывается.
ColumnLayout {
    id: page

    property var win: null
    property string tab: "emoji"    // emoji | kaomoji
    property string query: ""
    property var emojiAll: []
    property var kaomojiAll: []
    property bool emojiReady: false
    property bool kaomojiReady: false
    property bool haveWtype: false

    visible: win !== null && win.mode === "panel" && win.page === "emoji"
    Layout.fillWidth: true
    spacing: Theme.dp(10)

    // Экранирование одинарных кавычек для sh.
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function parseEmoji(txt) {
        try {
            const j = JSON.parse(txt);
            page.emojiAll = j.emoji || [];
        } catch (e) {
            page.emojiAll = [];
        }
        page.emojiReady = true;
    }
    function parseKaomoji(txt) {
        try {
            const j = JSON.parse(txt);
            page.kaomojiAll = j.kaomoji || [];
        } catch (e) {
            page.kaomojiAll = [];
        }
        page.kaomojiReady = true;
    }

    // поиск по n и k, регистронезависимо
    function filterList(list) {
        const q = page.query.trim().toLowerCase();
        if (q === "")
            return list;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const it = list[i];
            if (((it.n || "") + " " + (it.k || "")).toLowerCase().indexOf(q) !== -1)
                out.push(it);
        }
        return out;
    }

    readonly property var results: page.filterList(page.tab === "emoji" ? page.emojiAll : page.kaomojiAll)
    readonly property bool ready: page.tab === "emoji" ? page.emojiReady : page.kaomojiReady

    function setTab(t) {
        page.tab = t;
        page.query = "";
        searchField.text = "";
    }

    function pick(text) {
        const q = page.shq(text);
        // payload передаём позиционным аргументом ($1): так безопасны $, `,
        // кавычки и бэкслеши, которые встречаются в каомодзи
        let cmd = "wl-copy " + q;
        if (page.haveWtype)
            cmd += "; setsid -f sh -c 'sleep 0.25; wtype \"$1\"' sh " + q;
        Quickshell.execDetached(["sh", "-c", cmd]);
        if (page.win && page.win.shell)
            page.win.shell.closeOverlays();
    }

    RowLayout { // вкладки + счётчик
        Layout.fillWidth: true
        spacing: Theme.dp(8)

        Chip {
            label: "Эмодзи"
            selected: page.tab === "emoji"
            onClicked: page.setTab("emoji")
        }
        Chip {
            label: "Каомодзи"
            selected: page.tab === "kaomoji"
            onClicked: page.setTab("kaomoji")
        }

        Item { Layout.fillWidth: true }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: page.results.length
            color: Theme.subtextDim
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }
    }

    TextField { // поиск
        id: searchField
        Layout.fillWidth: true
        placeholder: page.tab === "emoji" ? "Поиск эмодзи…" : "Поиск каомодзи…"
        onTextChanged: page.query = text
    }

    GridView {
        id: grid

        Layout.fillWidth: true
        Layout.preferredHeight: 380
        clip: true
        cellWidth: page.tab === "emoji" ? Theme.dp(40) : Theme.dp(112)
        cellHeight: page.tab === "emoji" ? Theme.dp(40) : Theme.dp(34)
        model: page.results
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle { // ховер-подсветка
                anchors.centerIn: parent
                width: page.tab === "emoji"
                     ? Math.min(parent.width, parent.height) - Theme.dp(4)
                     : parent.width - Theme.dp(4)
                height: page.tab === "emoji" ? width : parent.height - Theme.dp(2)
                radius: page.tab === "emoji" ? width / 2 : Theme.radiusSm
                color: Theme.text
                opacity: pickArea.containsMouse ? Theme.stateHover : 0

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
                text: modelData.e
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: Theme.text
                // эмодзи рисуем системным шрифтом (Roboto их не содержит)
                font.family: page.tab === "kaomoji" ? Theme.textFont : ""
                font.pixelSize: page.tab === "emoji" ? Theme.dp(24) : Theme.fs(14)
            }

            MouseArea {
                id: pickArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.pick(modelData.e)
            }
        }

        Text { // статус загрузки/пустоты
            anchors.centerIn: parent
            visible: grid.count === 0
            text: !page.ready ? "Загрузка…"
                : page.query !== "" ? "Ничего не найдено"
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
        onLoaded: page.parseEmoji(emojiFile.text())
        onLoadFailed: page.emojiReady = true
    }

    FileView { // ~/nimbus/assets/kaomoji.json
        id: kaomojiFile
        path: Quickshell.env("HOME") + "/nimbus/assets/kaomoji.json"
        watchChanges: false
        onLoaded: page.parseKaomoji(kaomojiFile.text())
        onLoadFailed: page.kaomojiReady = true
    }

    Process { // есть ли wtype в PATH
        id: wtypeCheck
        command: ["sh", "-c", "command -v wtype >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => page.haveWtype = exitCode === 0
    }
}
