import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Вкладка «Пакеты»: поиск по репозиториям Arch и AUR (paru -Ss), обновления
// (checkupdates + paru -Qua), установка/удаление/обновление. Установка AUR и
// обновление системы уходят в терминал (ghostty -e paru …), установка/удаление
// из репозиториев — через pkexec pacman. Удаление подтверждается вторым Enter.
ColumnLayout {
    id: tab

    property string query: ""
    property int sel: 0
    property var shell: null
    property bool active: false

    signal hovered(int index)

    // ── данные ────────────────────────────────────────────────────────
    property var results: []       // [{name, repo, version, desc, installed, aur}]
    property int repoUpdates: 0
    property int aurUpdates: 0
    property var updatesList: []   // строки обновлений репозиториев (checkupdates)
    property var aurList: []       // строки обновлений AUR (paru -Qua) — только показ
    property string pending: ""    // пакет, ожидающий подтверждения удаления
    property bool searching: false
    property int _cur: -1          // индекс последнего заголовка (для строки описания)

    readonly property bool searchMode: tab.query.trim().length >= 2
    readonly property int totalUpdates: tab.repoUpdates + tab.aurUpdates
    // показываем до 8 строк обновлений (репозитории, затем AUR)
    readonly property var detailLines: tab.updatesList.concat(tab.aurList).slice(0, 8)
    readonly property int count: tab.searchMode
        ? tab.results.length
        : (tab.totalUpdates > 0 ? 1 + Math.min(8, tab.updatesList.length) : 0)

    readonly property var selectedResult:
        (tab.sel >= 0 && tab.sel < tab.results.length) ? tab.results[tab.sel] : null
    readonly property string hintText: {
        const it = tab.selectedResult;
        if (!it) return "";
        if (!it.installed) return "Enter — установить";
        if (tab.pending === it.name) return "Ещё раз — удалить";
        return "Enter — удалить (дважды для подтверждения)";
    }

    implicitHeight: Theme.dp(400)
    spacing: Theme.dp(4)

    onSelChanged: tab.pending = ""

    onQueryChanged: {
        tab.pending = "";
        if (!tab.searchMode) {
            searchTimer.stop();
            if (searchProc.running) searchProc.running = false;
            tab.results = [];
            tab.searching = false;
        } else {
            searchTimer.restart();
        }
    }

    onActiveChanged: {
        if (!tab.active) return;
        tab.pending = "";
        tab.refreshUpdates();
        if (tab.searchMode) {
            searchTimer.stop();
            tab.doSearch();
        } else {
            tab.results = [];
        }
    }

    // ── действия ──────────────────────────────────────────────────────
    function runInTerminal(args) {
        Quickshell.execDetached(["ghostty", "-e"].concat(args));
    }

    function doSearch() {
        const q = tab.query.trim();
        if (q.length < 2) return;
        tab._cur = -1;
        tab.results = [];
        tab.searching = true;
        searchProc.command = ["env", "LC_ALL=C", "paru", "-Ss", "--", q];
        searchProc.running = false;
        searchProc.running = true;
    }

    function refreshUpdates() {
        tab.updatesList = [];
        tab.aurList = [];
        tab.repoUpdates = 0;
        tab.aurUpdates = 0;
        repoProc.running = false;
        repoProc.running = true;
        aurProc.running = false;
        aurProc.running = true;
    }

    function activate(index) {
        if (!tab.searchMode) {
            if (index === 0 && tab.totalUpdates > 0) {
                tab.runInTerminal(["paru", "-Syu"]);
                if (tab.shell) tab.shell.closeOverlays();
            }
            return;
        }
        const it = tab.results[index];
        if (!it) return;
        if (!it.installed) {
            if (it.aur) tab.runInTerminal(["paru", "-S", "--", it.name]);
            else Quickshell.execDetached(["pkexec", "pacman", "-S", "--noconfirm", "--", it.name]);
            if (tab.shell) tab.shell.closeOverlays();
            return;
        }
        if (tab.pending === it.name) {
            if (it.aur) tab.runInTerminal(["paru", "-Rns", "--", it.name]);
            else Quickshell.execDetached(["pkexec", "pacman", "-Rns", "--noconfirm", "--", it.name]);
            tab.pending = "";
            if (tab.shell) tab.shell.closeOverlays();
        } else {
            tab.pending = it.name;
        }
    }

    // ── разбор вывода paru -Ss ────────────────────────────────────────
    function _searchLine(line) {
        if (tab.results.length >= 200) return;
        const m = line.match(/^([^\s/]+)\/(\S+)\s+(\S+)/);
        if (m) {
            const repo = m[1];
            const arr = tab.results.slice();
            arr.push({
                name: m[2],
                repo: repo,
                version: m[3],
                desc: "",
                installed: /\[(?:Installed|Установлено)[:\]]/.test(line),
                aur: repo === "aur"
            });
            tab.results = arr;
            tab._cur = arr.length - 1;
            return;
        }
        if (/^\s+\S/.test(line) && tab._cur >= 0 && tab._cur < tab.results.length) {
            const arr = tab.results.slice();
            if (arr[tab._cur].desc === "") {
                arr[tab._cur].desc = line.trim();
                tab.results = arr;
            }
        }
    }

    function _repoLine(line) {
        const t = line.trim();
        if (t === "") return;
        const a = tab.updatesList.slice();
        a.push(t);
        tab.updatesList = a;
        tab.repoUpdates = a.length;
    }

    function _aurLine(line) {
        const t = line.trim();
        if (t === "") return;
        const a = tab.aurList.slice();
        a.push(t);
        tab.aurList = a;
        tab.aurUpdates = a.length;
    }

    // ── процессы ──────────────────────────────────────────────────────
    Process { // поиск repo + AUR
        id: searchProc
        command: ["env", "LC_ALL=C", "paru", "-Ss", "--", ""]
        stdout: SplitParser {
            onRead: (line) => tab._searchLine(line)
        }
        onExited: (exitCode) => tab.searching = false
    }

    Process { // обновления репозиториев (exit 1 — нет обновлений)
        id: repoProc
        command: ["checkupdates"]
        stdout: SplitParser {
            onRead: (line) => tab._repoLine(line)
        }
        onExited: (exitCode) => tab.repoUpdates = tab.updatesList.length
    }

    Process { // обновления AUR
        id: aurProc
        command: ["paru", "-Qua"]
        stdout: SplitParser {
            onRead: (line) => tab._aurLine(line)
        }
        onExited: (exitCode) => tab.aurUpdates = tab.aurList.length
    }

    Timer { // дебаунс поиска
        id: searchTimer
        interval: 300
        repeat: false
        onTriggered: tab.doSearch()
    }

    // ── содержимое ────────────────────────────────────────────────────
    Item { // режим поиска
        visible: tab.searchMode
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.dp(352)

        ListView {
            id: resultView

            anchors.fill: parent
            model: tab.results
            clip: true
            spacing: Theme.dp(4)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: rowItem

                required property var modelData
                required property int index

                width: resultView.width
                height: Theme.dp(40)

                Rectangle {
                    id: row

                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: rowItem.index === tab.sel ? Theme.accentContainer
                         : (rowMouse.containsMouse ? Theme.bgHover : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Theme.durQuick }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: tab.hovered(rowItem.index)
                        onClicked: tab.activate(rowItem.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(8)
                        anchors.rightMargin: Theme.dp(8)
                        spacing: Theme.dp(8)

                        // глиф пакета
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(24)
                            implicitHeight: Theme.dp(24)

                            Icon {
                                anchors.centerIn: parent
                                name: "inventory_2"
                                size: Theme.dp(16)
                                color: rowItem.index === tab.sel ? Theme.fgAccentContainer : Theme.subtext
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: rowItem.modelData.name
                                color: rowItem.index === tab.sel ? Theme.fgAccentContainer : Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyLarge")
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: rowItem.modelData.repo + " · " + rowItem.modelData.version
                                      + (rowItem.modelData.desc ? " · " + rowItem.modelData.desc : "")
                                color: rowItem.index === tab.sel ? Theme.fgAccentContainer : Theme.subtext
                                opacity: rowItem.index === tab.sel ? 0.75 : 1
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                                elide: Text.ElideRight
                            }
                        }

                        // бейдж «Установлено» / подтверждение удаления
                        Rectangle {
                            visible: rowItem.modelData.installed
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: badgeText.implicitWidth + Theme.dp(14)
                            implicitHeight: Theme.dp(20)
                            radius: Theme.pill(height)
                            color: Theme.bgTrack

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: tab.pending === rowItem.modelData.name ? "Ещё раз — удалить" : "Установлено"
                                color: Theme.subtext
                                font.family: Theme.textFont
                                font.pixelSize: Theme.fs(10)
                                font.weight: Theme.typeWeight("labelSmall")
                            }
                        }
                    }
                }
            }
        }

        Text { // пусто / идёт поиск
            anchors.centerIn: parent
            visible: resultView.count === 0
            text: tab.searching ? "Поиск…" : "Ничего не найдено"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }
    }

    Text { // подсказка по Enter
        visible: tab.searchMode && tab.results.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: Theme.dp(8)
        text: tab.hintText
        color: Theme.subtextDim
        elide: Text.ElideRight
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelSmall")
        font.weight: Theme.typeWeight("labelSmall")
    }

    ColumnLayout { // режим обновлений
        visible: !tab.searchMode
        Layout.fillWidth: true
        Layout.topMargin: Theme.dp(4)
        spacing: Theme.dp(6)

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.dp(8)
            text: tab.totalUpdates > 0
                ? "Обновления: " + tab.totalUpdates + " (репо " + tab.repoUpdates + ", AUR " + tab.aurUpdates + ")"
                : "Всё актуально 🎉"
            color: tab.totalUpdates > 0 ? Theme.text : Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyLarge")
            font.weight: Font.DemiBold
        }

        Item { // строка действия «Обновить всё в терминале»
            visible: tab.totalUpdates > 0
            Layout.fillWidth: true
            implicitHeight: Theme.dp(40)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: tab.sel === 0 ? Theme.accentContainer
                     : (actMouse.containsMouse ? Theme.bgHover : "transparent")

                Behavior on color {
                    ColorAnimation { duration: Theme.durQuick }
                }
            }

            MouseArea {
                id: actMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: tab.hovered(0)
                onClicked: tab.activate(0)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(8)
                anchors.rightMargin: Theme.dp(8)
                spacing: Theme.dp(8)

                Item {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Theme.dp(24)
                    implicitHeight: Theme.dp(24)

                    Icon {
                        anchors.centerIn: parent
                        name: "system_update_alt"
                        size: Theme.dp(16)
                        color: tab.sel === 0 ? Theme.fgAccentContainer : Theme.subtext
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Обновить всё в терминале"
                    color: tab.sel === 0 ? Theme.fgAccentContainer : Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodyLarge")
                    font.weight: Theme.typeWeight("bodyLarge")
                    elide: Text.ElideRight
                }
            }
        }

        Column { // строки обновлений (невыделяемые)
            Layout.fillWidth: true
            spacing: Theme.dp(2)

            Repeater {
                model: tab.detailLines

                delegate: Text {
                    required property var modelData

                    width: parent.width
                    leftPadding: Theme.dp(8)
                    text: modelData
                    color: Theme.subtextDim
                    elide: Text.ElideRight
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }
    }
}
