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
    property var results: []       // [{name, repo, version, desc, installed, aur, installedVer, votes, popularity}]
    property int repoUpdates: 0
    property int aurUpdates: 0
    property var updatesList: []   // строки обновлений репозиториев (checkupdates)
    property var aurList: []       // строки обновлений AUR (paru -Qua) — только показ
    property string pending: ""    // пакет, ожидающий подтверждения удаления
    property bool searching: false
    property int _cur: -1          // индекс последнего заголовка (для строки описания)

    // установленные версии (ленивый `pacman -Q`) и ленивое git-URL из AUR RPC
    property var installedVersions: ({})
    property string _verName: ""
    property var aurGitCache: ({})
    property string aurGitName: ""

    readonly property bool searchMode: tab.query.trim().length >= 2
    readonly property int totalUpdates: tab.repoUpdates + tab.aurUpdates
    // показываем до 8 строк обновлений (репозитории, затем AUR)
    readonly property var detailLines: tab.updatesList.concat(tab.aurList).slice(0, 8)
    readonly property int count: tab.searchMode
        ? tab.results.length
        : (tab.totalUpdates > 0 ? 1 + Math.min(8, tab.updatesList.length) : 0)

    readonly property var selectedResult:
        (tab.sel >= 0 && tab.sel < tab.results.length) ? tab.results[tab.sel] : null

    // индекс приложений: имя пакета → имя иконки темы (id без .desktop или
    // basename команды запуска), см. паттерн в WorkspacesRow.qml
    readonly property var appIconIndex: {
        const byPkg = {};
        for (const e of DesktopEntries.applications.values) {
            if (!e.icon) continue;
            const icon = String(e.icon);
            if (e.id) {
                let id = String(e.id);
                if (id.endsWith(".desktop")) id = id.slice(0, -8);
                if (id) byPkg[id.toLowerCase()] = icon;
            }
            const cmd = String(e.command || e.execString || "");
            if (cmd) {
                const first = cmd.trim().split(/\s+/)[0] || "";
                const base = first.split("/").pop();
                if (base) byPkg[base.toLowerCase()] = icon;
            }
        }
        return byPkg;
    }

    function iconForPkg(name) {
        const k = String(name || "").toLowerCase();
        if (k === "") return "";
        const icon = tab.appIconIndex[k];
        if (!icon) return "";
        return Quickshell.iconPath(icon, true) || "";
    }

    // подсказка по Enter для выбранной строки
    readonly property string hintText: {
        const it = tab.selectedResult;
        if (!it) return "";
        if (!it.installed) return "Enter — установить";
        if (tab.pending === it.name) return "Enter — подтвердить удаление";
        return "Enter — удалить, ещё раз — подтвердить";
    }

    // детали выбранной строки: repo · version · установлено · AUR-статистика
    readonly property string detailsText: {
        const it = tab.selectedResult;
        if (!it) return "";
        const parts = [it.repo, it.version];
        if (it.installed) {
            const v = it.installedVer || tab.installedVersions[it.name];
            parts.push("установлено: " + (v || "…"));
        }
        if (it.aur && (it.votes !== undefined || it.popularity !== undefined)) {
            const stat = [];
            if (it.votes !== undefined) stat.push("голоса " + it.votes);
            if (it.popularity !== undefined) stat.push("популярность " + it.popularity);
            if (stat.length > 0) parts.push(stat.join(" · "));
        }
        return parts.join(" · ");
    }

    implicitHeight: Theme.dp(400)
    spacing: Theme.dp(4)

    onSelChanged: {
        tab.pending = "";
        tab._maybeFetchInstalled();
    }

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

    onSelectedResultChanged: tab._maybeFetchInstalled()

    // ── действия ──────────────────────────────────────────────────────
    function runInTerminal(args) {
        Quickshell.execDetached(["ghostty", "-e"].concat(args));
    }

    // ленивое получение установленной версии выбранного пакета
    function _maybeFetchInstalled() {
        const it = tab.selectedResult;
        if (it && it.installed && !it.installedVer)
            tab.ensureInstalledVersion(it.name);
    }

    function ensureInstalledVersion(name) {
        if (!name) return;
        if (tab.installedVersions[name] !== undefined) return;
        if (tab._verName === name && verProc.running) return;
        tab._verName = name;
        verProc.command = ["pacman", "-Q", "--", name];
        verProc.running = false;
        verProc.running = true;
    }

    function _verLine(line) {
        const m = String(line).trim().match(/^(\S+)\s+(\S+)/);
        if (!m) return;
        const name = tab._verName;
        if (!name || m[1] !== name) return;
        const map = Object.assign({}, tab.installedVersions);
        map[name] = m[2];
        tab.installedVersions = map;
    }

    function openAur(name) {
        if (!name) return;
        Quickshell.execDetached(["xdg-open", "https://aur.archlinux.org/packages/" + name]);
    }

    function openArch(name) {
        if (!name) return;
        Quickshell.execDetached(["xdg-open", "https://archlinux.org/packages/?q=" + name]);
    }

    // ленивый AUR RPC: разрешаем homepage (Git) выбранного AUR-пакета
    function openAurGit(name) {
        if (!name) return;
        const cached = tab.aurGitCache[name];
        if (cached !== undefined) {
            if (cached) Quickshell.execDetached(["xdg-open", cached]);
            return;
        }
        tab.aurGitName = name;
        aurInfoProc.command = ["curl", "-s", "--max-time", "15",
                               "https://aur.archlinux.org/rpc/v5/info?arg[]=" + name];
        aurInfoProc.running = false;
        aurInfoProc.running = true;
    }

    function _aurInfoDone(txt) {
        let url = "";
        try {
            const j = JSON.parse(String(txt || ""));
            if (j && j.results && j.results.length > 0 && j.results[0].URL)
                url = String(j.results[0].URL);
        } catch (e) {}
        const name = tab.aurGitName;
        if (name) {
            const map = Object.assign({}, tab.aurGitCache);
            map[name] = url;
            tab.aurGitCache = map;
        }
        if (url) Quickshell.execDetached(["xdg-open", url]);
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
                // сначала скрываем лончер, затем запускаем обновление
                if (tab.shell) tab.shell.closeOverlays();
                tab.runInTerminal(["paru", "-Syu"]);
            }
            return;
        }
        const it = tab.results[index];
        if (!it) return;
        if (!it.installed) {
            if (tab.shell) tab.shell.closeOverlays();
            if (it.aur) tab.runInTerminal(["paru", "-S", "--", it.name]);
            else Quickshell.execDetached(["pkexec", "pacman", "-S", "--noconfirm", "--", it.name]);
            return;
        }
        if (tab.pending === it.name) {
            if (tab.shell) tab.shell.closeOverlays();
            if (it.aur) tab.runInTerminal(["paru", "-Rns", "--", it.name]);
            else Quickshell.execDetached(["pkexec", "pacman", "-Rns", "--noconfirm", "--", it.name]);
            tab.pending = "";
        } else {
            tab.pending = it.name;
        }
    }

    // ── разбор вывода paru -Ss ────────────────────────────────────────
    function _installedVerFromHeader(line) {
        const m = line.match(/\[(?:Installed|Установлено)(?::\s*([^\]\[]+?))?\]/);
        return (m && m[1]) ? m[1].trim() : "";
    }

    function _aurStats(rest) {
        let votes;
        let popularity;
        const v = rest.match(/\+\s*(\d+)/);
        if (v) votes = parseInt(v[1], 10);
        const p = rest.match(/~\s*([0-9]+\.[0-9]+)/);
        if (p) popularity = parseFloat(p[1]);
        return { votes: votes, popularity: popularity };
    }

    function _searchLine(line) {
        if (tab.results.length >= 200) return;
        const m = line.match(/^([^\s/]+)\/(\S+)\s+(\S+)(.*)$/);
        if (m) {
            const repo = m[1];
            const aur = repo === "aur";
            const stats = aur ? tab._aurStats(m[4] || "") : {};
            const arr = tab.results.slice();
            arr.push({
                name: m[2],
                repo: repo,
                version: m[3],
                desc: "",
                installed: /\[(?:Installed|Установлено)[:\]]/.test(line),
                aur: aur,
                installedVer: tab._installedVerFromHeader(line),
                votes: stats.votes,
                popularity: stats.popularity
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

    Process { // ленивое получения версии установленного пакета
        id: verProc
        command: ["pacman", "-Q", "--", ""]
        stdout: SplitParser {
            onRead: (line) => tab._verLine(line)
        }
    }

    Process { // ленивый AUR RPC: homepage пакета
        id: aurInfoProc
        command: ["curl", "-s", "--max-time", "15", "https://aur.archlinux.org/rpc/v5/info?arg[]="]
        stdout: StdioCollector {
            id: aurInfoOut
        }
        onExited: (exitCode) => tab._aurInfoDone(aurInfoOut.text)
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
        Layout.preferredHeight: Theme.dp(320)

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

                readonly property bool pendingRemove: tab.pending === rowItem.modelData.name
                readonly property string pkgIcon: rowItem.modelData.installed
                    ? tab.iconForPkg(rowItem.modelData.name) : ""
                readonly property bool hasIcon: rowItem.pkgIcon !== ""

                width: resultView.width
                height: Theme.dp(40)

                Rectangle {
                    id: row

                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: rowItem.index === tab.sel ? Theme.accentContainer
                         : (rowMouse.containsMouse ? Theme.bgHover : "transparent")
                    border.width: rowItem.pendingRemove ? Theme.dp(1) : 0
                    border.color: Theme.error

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

                        // иконка приложения (установленные с резолвом) или глиф пакета
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(28)
                            implicitHeight: Theme.dp(28)

                            AppIcon {
                                anchors.centerIn: parent
                                visible: rowItem.hasIcon
                                source: rowItem.pkgIcon
                                size: 26
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: !rowItem.hasIcon
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
                            color: rowItem.pendingRemove ? Theme.errorContainer : Theme.bgTrack
                            border.width: rowItem.pendingRemove ? Theme.dp(1) : 0
                            border.color: Theme.error

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: rowItem.pendingRemove ? "Подтвердить удаление?" : "Установлено"
                                color: rowItem.pendingRemove ? Theme.fgErrorContainer : Theme.subtext
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

    // ── подвал выбранной строки: детали + ссылки ──────────────────────
    ColumnLayout {
        id: footer

        visible: tab.searchMode && tab.selectedResult !== null
        Layout.fillWidth: true
        Layout.leftMargin: Theme.dp(8)
        Layout.rightMargin: Theme.dp(8)
        spacing: Theme.dp(4)

        Text { // repo · version · установлено · AUR-статистика
            Layout.fillWidth: true
            text: tab.detailsText
            color: Theme.subtext
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(6)

            Text { // подсказка по Enter
                id: hint
                Layout.fillWidth: true
                text: tab.hintText
                color: hint.pendingHint ? Theme.error : Theme.subtextDim
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")

                readonly property bool pendingHint: tab.selectedResult !== null
                    && tab.pending === tab.selectedResult.name
            }

            Chip {
                visible: tab.selectedResult !== null && tab.selectedResult.aur
                label: "AUR"
                icon: "open_in_new"
                onClicked: if (tab.selectedResult) tab.openAur(tab.selectedResult.name)
            }
            Chip {
                visible: tab.selectedResult !== null && tab.selectedResult.aur
                label: "Git"
                icon: "link"
                onClicked: if (tab.selectedResult) tab.openAurGit(tab.selectedResult.name)
            }
            Chip {
                visible: tab.selectedResult !== null && !tab.selectedResult.aur
                label: "archlinux.org"
                icon: "open_in_new"
                onClicked: if (tab.selectedResult) tab.openArch(tab.selectedResult.name)
            }
        }
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
