import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Вкладка «Пакеты».
//  • Пустой запрос — список УСТАНОВЛЕННЫХ приложений (DesktopEntries ∩
//    `pacman -Qq`) с реальными иконками; клик/Enter по строке открывает панель
//    деталей (`pacman -Qi`: описание, зависимости, размер/сборщик/дата).
//  • Поиск (≥2 символов) — прежний `paru -Ss`: установка репозиториев через
//    pkexec pacman, AUR — в терминале. Enter по УСТАНОВЛЕННОМУ результату тоже
//    открывает ту же панель деталей с кнопкой удаления.
//  • Удаление живёт в панели деталей: первый клик — подтверждение (красный чип),
//    второй — собственно удаление (AUR → терминал paru -Rns, репо → pkexec).
//  • Обновления (`checkupdates` + `paru -Qua`) — компактная карточка сверху,
//    кнопка «Обновить всё» нажимается мышью и НЕ участвует в клавиатурном выборе.
//  • Все действия лончера вызывают closeOverlays() ПЕРВЫМ делом.
ColumnLayout {
    id: tab

    property string query: ""
    property int sel: 0
    property var shell: null
    property bool active: false
    property int workspaceHeight: Theme.dp(440)

    signal hovered(int index)
    signal selectionRequested(int index)

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
    property var aurGitCache: ({}) // pkg → homepage URL ("" — не в AUR)
    property string aurGitName: ""
    property var aurSet: ({})      // pkg → true, если пакет есть в AUR (из RPC)
    property bool _aurWantOpen: false

    // ── список установленных приложений ──────────────────────────────
    property var installedSet: ({}) // pkg → true (`pacman -Qq`, one-shot)
    property var _installedAcc: ({})
    property bool _installedLoaded: false
    property bool _installedStarted: false

    // ── детали (`pacman -Qi`) ─────────────────────────────────────────
    property bool detailsOpen: false
    property var qiCache: ({})     // pkg → {data: {…}, code: int}
    property var qiData: ({})
    property string qiName: ""
    property string _qiField: ""

    readonly property bool searchMode: tab.query.trim().length >= 2
    readonly property int totalUpdates: tab.repoUpdates + tab.aurUpdates
    readonly property int detailsHeight: Math.min(Theme.dp(184), Math.max(Theme.dp(120), tab.workspaceHeight * 0.38))
    // показываем до 8 строк обновлений (репозитории, затем AUR)
    readonly property var detailLines: tab.updatesList.concat(tab.aurList).slice(0, 8)
    // Подстраиваем строки обновлений под высоту рабочей области и карточку деталей.
    readonly property int detailLineLimit: tab.detailsOpen
        ? Math.max(0, Math.min(3, Math.floor((tab.workspaceHeight - tab.detailsHeight - Theme.dp(150)) / Theme.dp(18))))
        : Math.max(0, Math.min(8, Math.floor((tab.workspaceHeight - Theme.dp(220)) / Theme.dp(18))))
    readonly property var shownDetailLines: tab.detailLines.slice(0, tab.detailLineLimit)
    readonly property int hiddenDetailLines: Math.max(0, tab.totalUpdates - tab.shownDetailLines.length)
    readonly property int count: tab.searchMode
        ? tab.results.length
        : tab.appsList.length

    readonly property var selectedResult:
        (tab.sel >= 0 && tab.sel < tab.results.length) ? tab.results[tab.sel] : null

    // пакет → иконка темы (id без .desktop или basename команды запуска)
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
            const base = tab._cmdBasename(e);
            if (base) byPkg[base.toLowerCase()] = icon;
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

    // первый исполняемый токен команды записи (без path, без `env VAR=…`)
    function _cmdBasename(e) {
        let first = "";
        if (Array.isArray(e.command) && e.command.length > 0) first = String(e.command[0]);
        else {
            const s = String(e.execString || e.command || "").trim();
            first = s.split(/\s+/)[0] || "";
        }
        // пропускаем обёртку `env FOO=bar prog …`
        if (first === "env") {
            const tok = String(e.execString || "").trim().split(/\s+/);
            for (let i = 1; i < tok.length; i++) {
                if (tok[i].indexOf("=") === -1) { first = tok[i]; break; }
            }
        }
        return first.split("/").pop();
    }

    // кандидат-пакет для .desktop: id без ".desktop", иначе basename команды.
    // Если id не совпал с установленным — пробуем basename команды (GNOME/KDE
    // часто именуют файл с неймспейсом, а пакет — по бинарю).
    function _pkgForEntry(e) {
        const inst = tab.installedSet;
        let id = "";
        if (e.id) {
            id = String(e.id);
            if (id.endsWith(".desktop")) id = id.slice(0, -8);
        }
        if (id !== "" && inst[id]) return id;
        const base = tab._cmdBasename(e);
        if (base && inst[base]) return base;
        return "";
    }

    // установленные приложения: {pkg, name, icon}, дедуп по pkg, сорт по имени (ru)
    readonly property var appsList: {
        const inst = tab.installedSet;
        const out = [];
        const seen = {};
        for (const e of DesktopEntries.applications.values) {
            const pkg = tab._pkgForEntry(e);
            if (!pkg || seen[pkg]) continue;
            seen[pkg] = true;
            const icon = e.icon ? (Quickshell.iconPath(String(e.icon), true) || "") : "";
            out.push({ pkg: pkg, name: String(e.name || pkg), icon: icon });
        }
        out.sort((a, b) => a.name.localeCompare(b.name, "ru"));
        return out;
    }

    // цель панели деталей: выбранное приложение (пустой запрос) или
    // установленный результат поиска
    readonly property var detailTarget: {
        if (!tab.detailsOpen) return null;
        if (tab.searchMode) {
            const it = tab.selectedResult;
            if (!it || !it.installed) return null;
            return { pkg: it.name, name: it.name, icon: tab.iconForPkg(it.name), aur: !!it.aur };
        }
        const a = tab.appsList[tab.sel];
        if (!a) return null;
        return { pkg: a.pkg, name: a.name, icon: a.icon, aur: false };
    }
    readonly property string detailPkg: tab.detailTarget ? tab.detailTarget.pkg : ""
    readonly property bool detailAur: {
        if (!tab.detailTarget) return false;
        if (tab.searchMode) return !!tab.detailTarget.aur;
        return tab.aurSet[tab.detailTarget.pkg] === true;
    }

    // разобранный `pacman -Qi`
    readonly property var detailInfo: {
        if (!tab.detailTarget) return null;
        const c = tab.qiCache[tab.detailTarget.pkg];
        return c ? c.data : null;
    }
    readonly property bool detailLoading: tab.detailTarget !== null && tab.detailInfo === null
    readonly property string dDescription: tab.detailInfo ? String(tab.detailInfo["Description"] || "") : ""
    readonly property string dVersion: tab.detailInfo ? String(tab.detailInfo["Version"] || "") : ""
    readonly property string dSize: tab.detailInfo ? String(tab.detailInfo["Installed Size"] || "") : ""
    readonly property string dPackager: tab.detailInfo ? String(tab.detailInfo["Packager"] || "") : ""
    readonly property string dDate: tab.detailInfo ? String(tab.detailInfo["Install Date"] || "") : ""
    readonly property var dDeps: tab.detailInfo ? tab._splitList(tab.detailInfo["Depends On"]) : []
    readonly property var dRequired: tab.detailInfo ? tab._splitList(tab.detailInfo["Required By"]) : []
    readonly property var dOptional: tab.detailInfo ? tab._splitOptional(tab.detailInfo["Optional Deps"]) : []
    readonly property string dMeta: [tab.dSize, tab.dPackager, tab.dDate].filter((s) => s !== "").join("  ·  ")

    function _splitList(v) {
        if (!v) return [];
        const s = String(v).trim();
        if (s === "" || s === "None" || s === "Нет") return [];
        return s.split(/\s+/).filter((x) => x !== "" && x !== "None" && x !== "Нет");
    }

    function _splitOptional(v) {
        if (!v) return [];
        return String(v).split("\n").map((s) => s.trim())
            .filter((s) => s !== "" && s !== "None" && s !== "Нет");
    }

    // подсказка по Enter для выбранной строки поиска
    readonly property string hintText: {
        const it = tab.selectedResult;
        if (!it) return "";
        if (!it.installed) return "Enter — установить";
        return "Enter — подробнее";
    }

    // детали выбранной строки поиска: repo · version · установлено · AUR-статистика
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

    spacing: Theme.dp(4)

    onSelChanged: {
        tab.pending = "";
        tab._maybeFetchInstalled();
        if (!tab.searchMode && tab.sel >= 0 && tab.sel < appView.count)
            appView.positionViewAtIndex(tab.sel, ListView.Contain);
    }

    onQueryChanged: {
        tab.pending = "";
        tab.detailsOpen = false;
        // читаем длину напрямую: searchMode может ещё не пересчитаться на этом
        // кадре (важно при вставке/мгновенной смене всего запроса)
        if (tab.query.trim().length < 2) {
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
        tab.detailsOpen = false;
        tab.loadInstalled();
        tab.refreshUpdates();
        if (tab.searchMode) {
            searchTimer.stop();
            tab.doSearch();
        } else {
            tab.results = [];
        }
    }

    onSelectedResultChanged: tab._maybeFetchInstalled()
    onDetailTargetChanged: tab._ensureDetails()

    // ── действия ──────────────────────────────────────────────────────
    function runInTerminal(args) {
        Quickshell.execDetached(["ghostty", "-e"].concat(args));
    }

    function openDetails() {
        tab.pending = "";
        tab.detailsOpen = true;
    }

    function closeDetails() {
        tab.detailsOpen = false;
        tab.pending = "";
    }

    // ленивое получение установленной версии: в поиске — для выбранного
    // результата, в режиме приложений — для выбранной строки
    function _maybeFetchInstalled() {
        if (!tab.searchMode) {
            const a = tab.appsList[tab.sel];
            if (a) tab.ensureInstalledVersion(a.pkg);
            return;
        }
        const it = tab.selectedResult;
        if (it && it.installed && !it.installedVer)
            tab.ensureInstalledVersion(it.name);
    }

    // подпись строки приложения: версия, если уже известна, иначе имя пакета
    function appSub(a) {
        if (!a) return "";
        const v = tab.installedVersions[a.pkg];
        return v ? v : a.pkg;
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

    // ── установленные пакеты (one-shot, кэш) ──────────────────────────
    function loadInstalled() {
        if (tab._installedLoaded || tab._installedStarted) return;
        tab._installedStarted = true;
        tab._installedAcc = {};
        listProc.running = false;
        listProc.running = true;
    }

    function _installedLine(line) {
        const p = String(line).trim();
        if (p !== "") tab._installedAcc[p] = true;
    }

    function _installedExit(exitCode) {
        tab.installedSet = tab._installedAcc;
        tab._installedLoaded = (exitCode === 0);
        tab._installedStarted = false;
    }

    // ── детали: ленивый `pacman -Qi` ──────────────────────────────────
    function _ensureDetails() {
        const t = tab.detailTarget;
        if (!t) return;
        tab.ensureQi(t.pkg);
        if (!tab.searchMode && tab.aurSet[t.pkg] === undefined)
            tab.ensureAurInfo(t.pkg, false);
    }

    function ensureQi(name) {
        if (!name) return;
        if (tab.qiCache[name] !== undefined) return;
        if (tab.qiName === name && qiProc.running) return;
        tab.qiName = name;
        tab.qiData = {};
        tab._qiField = "";
        qiProc.command = ["env", "LC_ALL=C", "pacman", "-Qi", "--", name];
        qiProc.running = false;
        qiProc.running = true;
    }

    // поле начинается с `^[A-Z][A-Za-z ]* *:`; продолжения — с отступа
    function _qiLine(line) {
        const m = String(line).match(/^([A-Z][A-Za-z ]*?)\s*:\s?(.*)$/);
        if (m) {
            tab._qiField = m[1].trim();
            tab.qiData[tab._qiField] = m[2];
            return;
        }
        if (tab._qiField !== "" && /^\s+\S/.test(line)) {
            tab.qiData[tab._qiField] = String(tab.qiData[tab._qiField] || "")
                + "\n" + String(line).trim();
        }
    }

    function _qiExit(exitCode) {
        const name = tab.qiName;
        if (!name) return;
        const map = Object.assign({}, tab.qiCache);
        map[name] = { data: tab.qiData, code: exitCode };
        tab.qiCache = map;
    }

    function openAur(name) {
        if (!name) return;
        Quickshell.execDetached(["xdg-open", "https://aur.archlinux.org/packages/" + name]);
    }

    function openArch(name) {
        if (!name) return;
        Quickshell.execDetached(["xdg-open", "https://archlinux.org/packages/?q=" + name]);
    }

    // ленивый AUR RPC (кэш): homepage + факт наличия пакета в AUR
    function ensureAurInfo(name, openWhenReady) {
        if (!name) return;
        const cached = tab.aurGitCache[name];
        if (cached !== undefined) {
            if (openWhenReady && cached) Quickshell.execDetached(["xdg-open", cached]);
            return;
        }
        if (tab.aurGitName === name && aurInfoProc.running) {
            tab._aurWantOpen = openWhenReady;
            return;
        }
        tab.aurGitName = name;
        tab._aurWantOpen = openWhenReady;
        aurInfoProc.command = ["curl", "-s", "--max-time", "15",
                               "https://aur.archlinux.org/rpc/v5/info?arg[]=" + name];
        aurInfoProc.running = false;
        aurInfoProc.running = true;
    }

    function openAurGit(name) {
        tab.ensureAurInfo(name, true);
    }

    function _aurInfoDone(txt) {
        let url = "";
        let aur = false;
        try {
            const j = JSON.parse(String(txt || ""));
            if (j && j.results && j.results.length > 0) {
                aur = true;
                url = String(j.results[0].URL || "");
            }
        } catch (e) {}
        const name = tab.aurGitName;
        if (name) {
            const map = Object.assign({}, tab.aurGitCache);
            map[name] = url;
            tab.aurGitCache = map;
            const set = Object.assign({}, tab.aurSet);
            set[name] = aur;
            tab.aurSet = set;
        }
        if (url && tab._aurWantOpen) Quickshell.execDetached(["xdg-open", url]);
        tab._aurWantOpen = false;
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

    // «Обновить всё» — только по клику мышью (вне клавиатурного выбора)
    function updateAll() {
        if (tab.shell) tab.shell.closeOverlays();
        tab._installedLoaded = false;
        tab.runInTerminal(["paru", "-Syu"]);
    }

    // удаление текущей цели деталей: первый вызов — подтверждение
    function removeDetail() {
        const t = tab.detailTarget;
        if (!t) return;
        if (tab.pending !== t.pkg) {
            tab.pending = t.pkg;
            return;
        }
        if (tab.shell) tab.shell.closeOverlays();
        tab._installedLoaded = false;
        if (tab.detailAur) tab.runInTerminal(["paru", "-Rns", "--", t.pkg]);
        else Quickshell.execDetached(["pkexec", "pacman", "-Rns", "--noconfirm", "--", t.pkg]);
        tab.pending = "";
    }

    function activate(index) {
        if (!tab.searchMode) {
            const a = tab.appsList[index];
            if (a) tab.openDetails();
            return;
        }
        const it = tab.results[index];
        if (!it) return;
        if (!it.installed) {
            if (tab.shell) tab.shell.closeOverlays();
            tab._installedLoaded = false;
            if (it.aur) tab.runInTerminal(["paru", "-S", "--", it.name]);
            else Quickshell.execDetached(["pkexec", "pacman", "-S", "--noconfirm", "--", it.name]);
            return;
        }
        tab.openDetails();
    }

    function moveSel(delta) {
        if (tab.count > 0) tab.selectionRequested(tab.sel + delta);
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

    Process { // установленные пакеты (one-shot)
        id: listProc
        command: ["pacman", "-Qq"]
        stdout: SplitParser {
            onRead: (line) => tab._installedLine(line)
        }
        onExited: (exitCode) => tab._installedExit(exitCode)
    }

    Process { // ленивое получения версии установленного пакета
        id: verProc
        command: ["pacman", "-Q", "--", ""]
        stdout: SplitParser {
            onRead: (line) => tab._verLine(line)
        }
    }

    Process { // ленивые детали пакета
        id: qiProc
        command: ["env", "LC_ALL=C", "pacman", "-Qi", "--", ""]
        stdout: SplitParser {
            onRead: (line) => tab._qiLine(line)
        }
        onExited: (exitCode) => tab._qiExit(exitCode)
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

    // ── режим поиска ──────────────────────────────────────────────────
    Item {
        visible: tab.searchMode
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        Layout.preferredHeight: tab.detailsOpen ? Theme.dp(150) : Theme.dp(300)

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
                height: Theme.dp(52)

                ListItem {
                    id: resultSurface

                    anchors.fill: parent
                    headline: rowItem.modelData.name
                    headlineRole: "bodyLarge"
                    headlineWeight: Theme.typeWeight("bodyLarge")
                    supporting: rowItem.modelData.repo + " · " + rowItem.modelData.version
                        + (rowItem.modelData.desc ? " · " + rowItem.modelData.desc : "")
                    supportingRole: "bodySmall"
                    textSpacing: 0
                    selected: rowItem.index === tab.sel
                    clickable: true
                    containerColor: "transparent"
                    stateTint: rowItem.index === tab.sel ? Theme.fgSecondaryContainer : Theme.text
                    outerRadius: Theme.rad(14)
                    innerRadius: Theme.rad(14)
                    leadingMargin: Theme.dp(16)
                    leadingTextSpacing: Theme.dp(12)
                    textTrailingSpacing: rowItem.modelData.installed ? Theme.dp(12) : 0
                    trailingMargin: Theme.dp(16)
                    trailingSpacing: 0
                    borderWidth: rowItem.pendingRemove ? Theme.dp(1) : 0
                    borderColor: Theme.error
                    onClicked: tab.activate(rowItem.index)

                    leading: Item {
                        anchors.fill: parent

                        Rectangle {
                            anchors.fill: parent
                            visible: !rowItem.hasIcon
                            radius: Math.round(parent.width * 0.35)
                            color: Theme.bgTile
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            visible: rowItem.hasIcon
                            source: rowItem.pkgIcon
                            size: Theme.dp(36)
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !rowItem.hasIcon
                            name: "inventory_2"
                            size: Theme.dp(22)
                            color: rowItem.index === tab.sel ? Theme.fgSecondaryContainer : Theme.subtext
                        }
                    }

                    trailing: Rectangle {
                        visible: rowItem.modelData.installed
                        anchors.verticalCenter: parent.verticalCenter
                        width: badgeText.implicitWidth + Theme.dp(14)
                        height: Theme.dp(20)
                        radius: Theme.pill(height)
                        color: rowItem.pendingRemove ? Theme.errorContainer : Theme.bgTrack
                        border.width: rowItem.pendingRemove ? Theme.dp(1) : 0
                        border.color: Theme.error

                        LText {
                            id: badgeText
                            anchors.centerIn: parent
                            role: "labelSmall"
                            size: Theme.fs(10)
                            text: rowItem.pendingRemove ? "Подтвердить удаление?" : "Установлено"
                            color: rowItem.pendingRemove ? Theme.fgErrorContainer : Theme.subtext
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: if (hovered) tab.hovered(rowItem.index)
                }

            }
        }

        LText { // пусто / идёт поиск
            anchors.centerIn: parent
            visible: resultView.count === 0
            text: tab.searching ? "Поиск…" : "Ничего не найдено"
            role: "bodyMedium"
            color: Theme.subtext
        }
    }

    // ── подвал выбранной строки поиска (когда детали закрыты) ─────────
    ColumnLayout {
        id: searchFooter

        visible: tab.searchMode && !tab.detailsOpen && tab.selectedResult !== null
        Layout.fillWidth: true
        Layout.leftMargin: Theme.dp(8)
        Layout.rightMargin: Theme.dp(8)
        spacing: Theme.dp(4)

        LText { // repo · version · установлено · AUR-статистика
            Layout.fillWidth: true
            text: tab.detailsText
            color: Theme.subtext
            elide: Text.ElideRight
            role: "labelSmall"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(6)

            LText { // подсказка по Enter
                id: hint
                Layout.fillWidth: true
                role: "labelSmall"
                text: tab.hintText
                color: Theme.subtextDim
                elide: Text.ElideRight
            }

            Button {
                visible: tab.selectedResult !== null && tab.selectedResult.aur
                variant: "text"
                size: "s"
                text: "AUR"
                icon: "open_in_new"
                onClicked: if (tab.selectedResult) tab.openAur(tab.selectedResult.name)
            }
            Button {
                visible: tab.selectedResult !== null && tab.selectedResult.aur
                variant: "text"
                size: "s"
                text: "Git"
                icon: "link"
                onClicked: if (tab.selectedResult) tab.openAurGit(tab.selectedResult.name)
            }
            Button {
                visible: tab.selectedResult !== null && !tab.selectedResult.aur
                variant: "text"
                size: "s"
                text: "archlinux.org"
                icon: "open_in_new"
                onClicked: if (tab.selectedResult) tab.openArch(tab.selectedResult.name)
            }
        }
    }

    // ── режим по умолчанию: обновления + установленные приложения ─────
    ColumnLayout {
        id: defaultView

        visible: !tab.searchMode
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        spacing: Theme.dp(6)

        // карточка обновлений — акцентный контейнер (Lucid card anatomy)
        Rectangle {
            id: updatesCard

            visible: !tab.searchMode
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            implicitHeight: updatesCol.implicitHeight + Theme.dp(24)
            radius: Theme.shapeXl
            color: Theme.secondaryContainer

            ColumnLayout {
                id: updatesCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.dp(12)
                spacing: Theme.dp(8)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(8)

                    Icon {
                        Layout.alignment: Qt.AlignVCenter
                        name: tab.totalUpdates > 0 ? "system_update_alt" : "check_circle"
                        size: Theme.dp(20)
                        color: Theme.fgSecondaryContainer
                    }

                    LText {
                        Layout.fillWidth: true
                        role: "bodyLarge"
                        text: tab.totalUpdates > 0
                            ? "Обновления: " + tab.totalUpdates + " (репо " + tab.repoUpdates + ", AUR " + tab.aurUpdates + ")"
                            : "Всё актуально 🎉"
                        color: Theme.fgSecondaryContainer
                        elide: Text.ElideRight
                    }
                }

                // «Обновить всё» — кнопка (мышь), не входит в клавиатурный выбор
                Button {
                    visible: tab.totalUpdates > 0
                    Layout.alignment: Qt.AlignLeft
                    variant: "filled"
                    size: "s"
                    text: "Обновить всё"
                    icon: "system_update_alt"
                    onClicked: tab.updateAll()
                }

                Column { // строки обновлений (невыделяемые)
                    Layout.fillWidth: true
                    spacing: Theme.dp(2)

                    Repeater {
                        model: tab.shownDetailLines

                        delegate: LText {
                            required property var modelData
                            width: parent.width
                            role: "bodySmall"
                            text: modelData
                            color: Theme.alpha(Theme.fgSecondaryContainer, 0.8)
                            elide: Text.ElideRight
                        }
                    }

                    LText {
                        visible: tab.hiddenDetailLines > 0
                        width: parent.width
                        role: "bodySmall"
                        text: "и ещё " + tab.hiddenDetailLines
                        color: Theme.alpha(Theme.fgSecondaryContainer, 0.8)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // заголовок секции — Lucid list header: label primary + правило
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.dp(8)
            Layout.rightMargin: Theme.dp(8)
            Layout.topMargin: Theme.dp(6)
            spacing: Theme.dp(8)

            LText {
                Layout.alignment: Qt.AlignVCenter
                role: "labelLarge"
                text: "Приложения (" + tab.appsList.length + ")"
                color: Theme.primary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 1
                color: Theme.divider
            }
        }

        ListView { // установленные приложения
            id: appView

            visible: !tab.searchMode
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.dp(260)
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            model: tab.appsList
            clip: true
            spacing: Theme.dp(4)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: appRow

                required property var modelData
                required property int index

                readonly property bool hasIcon: appRow.modelData.icon !== ""

                width: appView.width
                height: Theme.dp(56)

                ListItem {
                    id: installedSurface

                    anchors.fill: parent
                    headline: appRow.modelData.name
                    headlineRole: "bodyLarge"
                    headlineWeight: Theme.typeWeight("bodyLarge")
                    supporting: tab.appSub(appRow.modelData)
                    supportingRole: "bodySmall"
                    textSpacing: 0
                    selected: appRow.index === tab.sel
                    clickable: true
                    containerColor: "transparent"
                    stateTint: appRow.index === tab.sel ? Theme.fgSecondaryContainer : Theme.text
                    outerRadius: Theme.rad(14)
                    innerRadius: Theme.rad(14)
                    leadingMargin: Theme.dp(16)
                    leadingTextSpacing: Theme.dp(12)
                    textTrailingSpacing: Theme.dp(12)
                    trailingMargin: Theme.dp(16)
                    trailingSpacing: 0
                    onClicked: tab.activate(appRow.index)

                    leading: Item {
                        anchors.fill: parent

                        Rectangle {
                            anchors.fill: parent
                            visible: !appRow.hasIcon
                            radius: Math.round(parent.width * 0.35)
                            color: Theme.bgTile
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            visible: appRow.hasIcon
                            source: appRow.modelData.icon
                            size: Theme.dp(36)
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !appRow.hasIcon
                            name: "inventory_2"
                            size: Theme.dp(22)
                            color: appRow.index === tab.sel ? Theme.fgSecondaryContainer : Theme.subtext
                        }
                    }

                    trailing: Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_right"
                        size: Theme.dp(20)
                        color: appRow.index === tab.sel ? Theme.fgSecondaryContainer : Theme.subtextDim
                    }
                }

                HoverHandler {
                    onHoveredChanged: if (hovered) tab.hovered(appRow.index)
                }

            }

            LText { // пусто / ещё грузится
                anchors.centerIn: parent
                visible: appView.count === 0
                text: tab._installedLoaded ? "Нет установленных приложений" : "Загрузка…"
                color: Theme.subtext
                role: "bodyMedium"
            }
        }
    }

    // ── панель деталей ────────────────────────────────────────────────
    Item {
        id: detailsPanel

        visible: tab.detailsOpen && tab.detailTarget !== null
        Layout.fillWidth: true
        Layout.preferredHeight: tab.detailsHeight
        Layout.minimumHeight: Math.min(Theme.dp(120), tab.workspaceHeight)

        Rectangle { // Lucid-карточка панели деталей
            anchors.fill: parent
            radius: Theme.shapeXl
            color: Theme.mHigh
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.dp(12)
            spacing: Theme.dp(4)

            Flickable {
                id: detailsFlick

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: detailsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                ColumnLayout {
                    id: detailsCol

                    width: detailsFlick.width
                    spacing: Theme.dp(4)

            RowLayout { // заголовок: иконка + имя + версия/источник
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                spacing: Theme.dp(8)

                Item {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Theme.dp(24)
                    implicitHeight: Theme.dp(24)

                    AppIcon {
                        anchors.centerIn: parent
                        visible: tab.detailTarget !== null && tab.detailTarget.icon !== ""
                        source: tab.detailTarget ? tab.detailTarget.icon : ""
                        size: Theme.dp(22)
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: tab.detailTarget === null || tab.detailTarget.icon === ""
                        name: "inventory_2"
                        size: Theme.dp(16)
                        color: Theme.subtext
                    }
                }

                LText {
                    Layout.fillWidth: true
                    role: "bodyLarge"
                    text: (tab.detailTarget ? tab.detailTarget.name : "")
                          + (tab.dVersion !== "" ? "  " + tab.dVersion : "")
                    color: Theme.text
                    elide: Text.ElideRight
                }
            }

            LText { // описание (перенос)
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                visible: tab.dDescription !== ""
                text: tab.dDescription
                color: Theme.text
                wrapMode: Text.WordWrap
                role: "bodySmall"
            }

            LText { // зависимости
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                visible: tab.dDeps.length > 0
                text: "<font color=\"" + Theme.subtextDim + "\">Зависит от (" + tab.dDeps.length + "):</font> "
                      + tab.dDeps.join("  ")
                textFormat: Text.StyledText
                color: Theme.subtext
                wrapMode: Text.WordWrap
                role: "bodySmall"
            }

            LText { // обратные зависимости
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                visible: tab.dRequired.length > 0
                text: "<font color=\"" + Theme.subtextDim + "\">Требуется для (" + tab.dRequired.length + "):</font> "
                      + tab.dRequired.join("  ")
                textFormat: Text.StyledText
                color: Theme.subtext
                wrapMode: Text.WordWrap
                role: "bodySmall"
            }

            LText { // опциональные зависимости
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                visible: tab.dOptional.length > 0
                text: "<font color=\"" + Theme.subtextDim + "\">Опционально:</font> "
                      + tab.dOptional.join("; ")
                textFormat: Text.StyledText
                color: Theme.subtext
                wrapMode: Text.WordWrap
                role: "bodySmall"
            }

            LText { // размер · сборщик · дата установки
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                visible: tab.dMeta !== ""
                text: tab.dMeta
                color: Theme.subtextDim
                wrapMode: Text.WordWrap
                role: "labelSmall"
            }

                    LText { // состояние загрузки
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.dp(4)
                        visible: tab.detailLoading
                        text: "Загрузка сведений…"
                        color: Theme.subtextDim
                        role: "labelSmall"
                    }
                }
            }

            RowLayout { // ссылки (text-кнопки) + удаление в error-контейнере
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                Layout.topMargin: Theme.dp(4)
                spacing: Theme.dp(6)

                Button {
                    visible: tab.detailAur
                    variant: "text"
                    size: "s"
                    text: "AUR"
                    icon: "open_in_new"
                    onClicked: if (tab.detailTarget) tab.openAur(tab.detailTarget.pkg)
                }
                Button {
                    visible: tab.detailAur
                    variant: "text"
                    size: "s"
                    text: "Git"
                    icon: "link"
                    onClicked: if (tab.detailTarget) tab.openAurGit(tab.detailTarget.pkg)
                }
                Button {
                    visible: !tab.detailAur
                    variant: "text"
                    size: "s"
                    text: "archlinux.org"
                    icon: "open_in_new"
                    onClicked: if (tab.detailTarget) tab.openArch(tab.detailTarget.pkg)
                }

                Item { Layout.fillWidth: true }

                // «Удалить» → первый клик — подтверждение (error-контейнер), второй — удаление
                Button {
                    readonly property bool armed: tab.detailTarget !== null
                        && tab.pending === tab.detailTarget.pkg

                    Layout.alignment: Qt.AlignVCenter
                    variant: armed ? "tonal" : "text"
                    danger: true
                    size: "s"
                    icon: "delete"
                    text: armed ? "Подтвердить удаление?" : "Удалить"
                    onClicked: tab.removeDetail()
                }
            }
        }
    }
}
