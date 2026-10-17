pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import "../../core"
import "../../ui"

// Вкладка «Процессы» в стиле Windows 11 Task Manager (Material 3 Expressive):
// - Тулбар: поиск, фильтр категорий («Все / Приложения / Фоновые»), пауза/пуск,
//   переключатель «Дерево / Список», кнопки «К окну» и «Снять задачу».
// - Заголовок таблицы с живыми итогами ЦП % и Память % и сортировкой ▲/▼.
// - Тепловая карта (heat-map) ячеек ЦП и Памяти.
// - Нижняя панель деталей выбранного процесса с быстрыми действиями и контекстное меню.
Item {
    id: tab

    property var shell: null
    // выбранный процесс: pid переживает перерисовки списка
    property int selectedPid: -1
    // сортировка списка и направление (по убыванию по умолчанию для ресурсов)
    property string sortBy: "cpu"
    property bool sortAsc: false
    // категория: "all" | "apps" | "bg"
    property string categoryFilter: "all"
    // режим отображения: дерево (true) или плоский список (false)
    property bool treeMode: true

    property var expanded: ({})
    // порядок строк между обновлениями для стабильности без прыжков
    property var _order: ({})
    property int rowCount: 0
    property int appsCount: 0
    property int bgCount: 0

    // контекстное меню: процесс и точка открытия
    property var menuProc: null
    property real menuX: 0
    property real menuY: 0
    property bool menuOpen: false
    property string armedAction: ""
    property int armedPid: -1

    ListModel { id: processModel }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    // геометрия колонок таблицы — общая для шапки и строк
    readonly property int cellPad: Theme.dp(10)
    readonly property int cellGap: Theme.dp(6)
    readonly property int colName: Theme.dp(250)
    readonly property int colStatus: Theme.dp(102)
    readonly property int colCpu: Theme.dp(86)
    readonly property int colMem: Theme.dp(112)
    readonly property int colThreads: Theme.dp(68)
    readonly property int colPidNice: Theme.dp(88)
    readonly property int menuW: Theme.dp(228)

    property string query: ""

    readonly property real screenAvailHeight: Screen.desktopAvailableHeight > 0
        ? Screen.desktopAvailableHeight : Screen.height

    // ── Сопоставление процессов с открытыми окнами Umbriel и иконками ──
    readonly property var iconIndex: {
        const byId = {};
        const byClass = {};
        const byExec = {};
        const entries = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        for (const e of entries) {
            if (!e || !e.icon) continue;
            if (e.id) {
                let idStr = String(e.id).toLowerCase();
                byId[idStr] = e.icon;
                if (idStr.endsWith(".desktop"))
                    byId[idStr.slice(0, -8)] = e.icon;
            }
            if (e.startupClass)
                byClass[String(e.startupClass).toLowerCase()] = e.icon;
            if (e.command && e.command.length > 0) {
                const base = String(e.command[0]).split("/").pop().toLowerCase();
                if (base) byExec[base] = e.icon;
            }
        }
        return { byId: byId, byClass: byClass, byExec: byExec };
    }

    readonly property var windowLookup: {
        const byPid = {};
        const byApp = {};
        const wins = Umbriel.windows || [];
        for (const w of wins) {
            if (!w) continue;
            if (w.pid)
                byPid[String(w.pid)] = w;
            if (w.app_id) {
                const raw = String(w.app_id).toLowerCase();
                byApp[raw] = w;
                const parts = raw.split(".");
                if (parts.length > 1)
                    byApp[parts[parts.length - 1]] = w;
            }
        }
        return { byPid: byPid, byApp: byApp };
    }

    function windowForProc(p) {
        if (!p) return null;
        const wl = tab.windowLookup;
        if (wl.byPid[String(p.pid)])
            return wl.byPid[String(p.pid)];
        const n = String(p.name || "").toLowerCase();
        if (n !== "" && wl.byApp[n])
            return wl.byApp[n];
        const c = String(p.comm || "").toLowerCase();
        if (c !== "" && wl.byApp[c])
            return wl.byApp[c];
        return null;
    }

    function iconPathForProc(name, comm, appId) {
        const ix = tab.iconIndex;
        const a = String(appId || "").toLowerCase();
        const n = String(name || "").toLowerCase();
        const c = String(comm || "").toLowerCase();
        const iconName = (a && (ix.byId[a] || ix.byClass[a] || ix.byExec[a]))
            || (n && (ix.byId[n] || ix.byClass[n] || ix.byExec[n]))
            || (c && (ix.byId[c] || ix.byClass[c] || ix.byExec[c]))
            || "";
        return iconName !== "" ? (Quickshell.iconPath(iconName, true) || "") : "";
    }

    // Живой объект выбранного процесса для тулбара и нижней панели деталей
    readonly property var selectedProc: {
        if (tab.selectedPid <= 0) return null;
        const list = ProcList.items || [];
        for (let i = 0; i < list.length; i++) {
            if (Number(list[i].pid) === tab.selectedPid) {
                const p = list[i];
                const w = tab.windowForProc(p);
                return {
                    pid: p.pid,
                    ppid: p.ppid,
                    user: p.user,
                    stat: p.stat,
                    state: p.state || (String(p.stat || "S")[0] || "S").toUpperCase(),
                    ni: p.ni,
                    threads: p.threads || p.nlwp || 1,
                    cpu: p.cpu,
                    mem: p.mem,
                    rss: p.rss || 0,
                    comm: p.comm || p.name,
                    name: p.name,
                    args: p.args,
                    hasWindow: w !== null,
                    winId: w && w.id !== undefined ? String(w.id) : "",
                    winTitle: w && w.title ? String(w.title) : ""
                };
            }
        }
        return null;
    }

    onVisibleChanged: if (!tab.visible) tab.closeMenu()

    Timer {
        id: disarmTimer
        interval: 4000
        onTriggered: {
            tab.armedAction = "";
            tab.armedPid = -1;
        }
    }

    onQueryChanged: { tab._order = ({}); tab.rebuild(); }
    onCategoryFilterChanged: { tab._order = ({}); tab.rebuild(); }
    onTreeModeChanged: { tab._order = ({}); tab.rebuild(); }
    onWindowLookupChanged: tab.rebuild()

    Connections {
        target: ProcList

        function onItemsChanged() {
            if (ProcList.items.length > 0)
                tab.rebuild();
        }
    }

    function fmtMemRss(bytes) {
        if (!isFinite(bytes) || bytes <= 0)
            return "0 МБ";
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(2) + " ГБ";
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " МБ";
        return Math.max(1, Math.round(bytes / 1024)) + " КБ";
    }

    function stateLabel(stateChar, hasWin) {
        if (hasWin) return "Окно";
        switch (String(stateChar || "S").toUpperCase()) {
        case "R": return "Активно";
        case "T": return "Остановлен";
        case "D": return "Ожидание I/O";
        case "Z": return "Зомби";
        default: return "Сон";
        }
    }

    function stateRank(p) {
        if (tab.windowForProc(p) !== null) return 0;
        const st = String(p.state || "S").toUpperCase();
        if (st === "R") return 1;
        if (st === "D") return 2;
        if (st === "T") return 3;
        if (st === "Z") return 4;
        return 5;
    }

    // Тепловая карта (Windows 11 Task Manager style heat-map tint)
    function heatColor(normVal, isSelected) {
        const v = Math.max(0, Math.min(1, isFinite(normVal) ? normVal : 0));
        if (isSelected)
            return Theme.alpha(Theme.primary, 0.18 + v * 0.22);
        if (v >= 0.65)
            return Theme.alpha(Theme.errorContainer, 0.35 + (v - 0.65) * 0.7);
        if (v >= 0.30)
            return Theme.alpha(Theme.warning, 0.16 + (v - 0.30) * 0.35);
        return Theme.alpha(Theme.primary, 0.06 + v * 0.38);
    }

    function _cmp(a, b) {
        const dir = tab.sortAsc ? 1 : -1;
        if (tab.sortBy === "mem") {
            const d = ((a.rss || a.mem) - (b.rss || b.mem)) * dir;
            if (d !== 0) return d;
        } else if (tab.sortBy === "threads") {
            const d = ((a.threads || 1) - (b.threads || 1)) * dir;
            if (d !== 0) return d;
        } else if (tab.sortBy === "name") {
            const d = String(a.name).localeCompare(String(b.name), "ru") * dir;
            if (d !== 0) return d;
        } else if (tab.sortBy === "pid") {
            const d = (a.pid - b.pid) * dir;
            if (d !== 0) return d;
        } else if (tab.sortBy === "status") {
            const d = (tab.stateRank(a) - tab.stateRank(b)) * (tab.sortAsc ? 1 : -1);
            if (d !== 0) return d;
        } else {
            const d = (a.cpu - b.cpu) * dir;
            if (d !== 0) return d;
        }
        return a.pid - b.pid;
    }

    function _rowData(row) {
        const p = row.proc;
        const w = row.win;
        const stChar = p.state || (String(p.stat || "S")[0] || "S").toUpperCase();
        const appId = w && w.app_id ? String(w.app_id) : "";
        return {
            pid: p.pid,
            ppid: p.ppid,
            ni: p.ni,
            threads: p.threads || p.nlwp || 1,
            cpu: p.cpu,
            mem: p.mem,
            rss: p.rss || 0,
            stat: p.stat,
            state: stChar,
            comm: p.comm || p.name,
            args: p.args,
            name: p.name,
            user: p.user,
            depth: row.depth,
            hasChildren: row.hasChildren,
            childCount: row.childCount || 0,
            expanded: row.expanded,
            hasWindow: w !== null,
            winId: w && w.id !== undefined ? String(w.id) : "",
            winTitle: w && w.title ? String(w.title) : "",
            iconPath: tab.iconPathForProc(p.name, p.comm, appId)
        };
    }

    function _syncProcessModel(rows) {
        const wanted = {};
        for (const row of rows)
            wanted[String(row.proc.pid)] = true;

        for (let i = processModel.count - 1; i >= 0; i--) {
            if (!wanted[String(processModel.get(i).pid)])
                processModel.remove(i);
        }

        for (let i = 0; i < rows.length; i++) {
            const data = tab._rowData(rows[i]);
            let found = -1;
            for (let j = i; j < processModel.count; j++) {
                if (Number(processModel.get(j).pid) === Number(data.pid)) {
                    found = j;
                    break;
                }
            }
            if (found === -1)
                processModel.insert(i, data);
            else if (found !== i)
                processModel.move(found, i, 1);

            const current = processModel.get(i);
            for (const role in data) {
                if (current[role] !== data[role])
                    processModel.setProperty(i, role, data[role]);
            }
        }
    }

    function rebuild() {
        const list = ProcList.items || [];
        const q = tab.query.trim().toLowerCase();

        let aCount = 0;
        let bCount = 0;
        const winCache = {};
        for (const p of list) {
            const w = tab.windowForProc(p);
            winCache[String(p.pid)] = w;
            if (w !== null) aCount++;
            else bCount++;
        }
        tab.appsCount = aCount;
        tab.bgCount = bCount;

        const matched = [];
        for (const p of list) {
            const hasW = winCache[String(p.pid)] !== null;
            if (tab.categoryFilter === "apps" && !hasW)
                continue;
            if (tab.categoryFilter === "bg" && hasW)
                continue;

            if (q !== "") {
                const pid = String(p.pid);
                if (String(p.name).toLowerCase().indexOf(q) === -1
                        && String(p.args).toLowerCase().indexOf(q) === -1
                        && String(p.user).toLowerCase().indexOf(q) === -1
                        && pid.indexOf(q) !== 0)
                    continue;
            }
            matched.push(p);
        }

        const out = [];
        if (!tab.treeMode) {
            // Плоский список
            const flatCmp = (a, b) => {
                const oa = tab._order[String(a.pid)];
                const ob = tab._order[String(b.pid)];
                const ha = oa !== undefined;
                const hb = ob !== undefined;
                if (ha && hb && oa !== ob)
                    return oa - ob;
                if (ha !== hb)
                    return ha ? -1 : 1;
                return tab._cmp(a, b);
            };
            const sorted = matched.slice().sort(flatCmp);
            for (const p of sorted) {
                out.push({
                    proc: p,
                    win: winCache[String(p.pid)] || null,
                    depth: 0,
                    hasChildren: false,
                    childCount: 0,
                    expanded: false
                });
            }
        } else {
            // Дерево по ppid
            const inSet = {};
            for (const p of matched)
                inSet[String(p.pid)] = true;
            const children = {};
            const roots = [];
            for (const p of matched) {
                const pp = String(p.ppid);
                if (p.ppid === p.pid || !inSet[pp])
                    roots.push(p);
                else
                    (children[pp] = children[pp] || []).push(p);
            }

            const subVal = {};
            const subCount = {};
            function _calcSub(p) {
                let m = tab.sortBy === "mem" ? (p.rss || p.mem)
                      : (tab.sortBy === "threads" ? (p.threads || 1) : p.cpu);
                let cnt = 0;
                for (const c of (children[String(p.pid)] || [])) {
                    cnt += 1 + _calcSub(c);
                    const cv = subVal[String(c.pid)] || 0;
                    m = tab.sortAsc ? Math.min(m, cv) : Math.max(m, cv);
                }
                subVal[String(p.pid)] = m;
                subCount[String(p.pid)] = cnt;
                return cnt;
            }
            for (const r of roots)
                _calcSub(r);

            const treeCmp = (a, b) => {
                const oa = tab._order[String(a.pid)];
                const ob = tab._order[String(b.pid)];
                const ha = oa !== undefined;
                const hb = ob !== undefined;
                if (ha && hb && oa !== ob)
                    return oa - ob;
                if (ha !== hb)
                    return ha ? -1 : 1;
                if (tab.sortBy === "cpu" || tab.sortBy === "mem" || tab.sortBy === "threads") {
                    const dir = tab.sortAsc ? 1 : -1;
                    const d = ((subVal[String(a.pid)] || 0) - (subVal[String(b.pid)] || 0)) * dir;
                    if (d !== 0) return d;
                }
                return tab._cmp(a, b);
            };
            roots.sort(treeCmp);
            for (const k in children)
                children[k].sort(treeCmp);

            const walk = (p, depth) => {
                const kids = children[String(p.pid)] || [];
                const ex = tab.expanded[String(p.pid)] !== false;
                out.push({
                    proc: p,
                    win: winCache[String(p.pid)] || null,
                    depth: depth,
                    hasChildren: kids.length > 0,
                    childCount: subCount[String(p.pid)] || kids.length,
                    expanded: ex
                });
                if (ex) {
                    for (const c of kids)
                        walk(c, depth + 1);
                }
            };
            for (const r of roots)
                walk(r, 0);
        }

        const savedY = listView.contentY;
        tab._syncProcessModel(out);
        tab.rowCount = matched.length;
        const order = {};
        for (let i = 0; i < out.length; i++)
            order[String(out[i].proc.pid)] = i;
        tab._order = order;
        listView.contentY = savedY;
        Qt.callLater(function() {
            listView.contentY = Math.min(savedY, Math.max(0, listView.contentHeight - listView.height));
        });
    }

    function setSort(k) {
        tab._order = ({});
        if (tab.sortBy === k) {
            tab.sortAsc = !tab.sortAsc;
        } else {
            tab.sortBy = k;
            tab.sortAsc = (k === "name" || k === "pid" || k === "status");
        }
        tab.rebuild();
    }

    function sortArrow(k) {
        if (tab.sortBy !== k) return "";
        return tab.sortAsc ? " ▲" : " ▼";
    }

    function toggleExpanded(pid) {
        const k = String(pid);
        tab.expanded[k] = !(tab.expanded[k] !== false);
        tab.rebuild();
    }

    function focusWindow(winId) {
        if (!winId) return;
        Quickshell.execDetached(["umbriel", "msg", "window-focus:" + winId]);
        if (tab.shell)
            tab.shell.closeOverlays();
    }

    function openMenu(proc, px, py) {
        tab.menuProc = proc;
        tab.armedAction = "";
        tab.armedPid = -1;
        disarmTimer.stop();
        tab.menuX = Math.max(Theme.dp(6), Math.min(px, tab.width - menuRect.width - Theme.dp(6)));
        tab.menuY = Math.max(Theme.dp(6), Math.min(py, tab.height - menuRect.height - Theme.dp(6)));
        tab.menuOpen = true;
    }

    function closeMenu() {
        tab.menuOpen = false;
        tab.menuProc = null;
        tab.armedAction = "";
        tab.armedPid = -1;
        disarmTimer.stop();
    }

    function runActionOn(p, action, requireConfirm) {
        if (!p) return;
        if (requireConfirm && (action === "term" || action === "kill9")) {
            if (tab.armedAction !== action || tab.armedPid !== p.pid) {
                tab.armedAction = action;
                tab.armedPid = p.pid;
                disarmTimer.restart();
                return;
            }
        }
        tab.armedAction = "";
        tab.armedPid = -1;
        disarmTimer.stop();
        tab.closeMenu();
        if (action === "term")
            ProcList.term(p.pid);
        else if (action === "kill9")
            ProcList.kill9(p.pid);
        else if (action === "stop")
            ProcList.stop(p.pid);
        else if (action === "cont")
            ProcList.cont(p.pid);
        else if (action === "niceUp")
            ProcList.renice(p.pid, p.ni + 5);
        else if (action === "niceDown")
            ProcList.renice(p.pid, p.ni - 5);
        else if (action === "niceReset")
            ProcList.renice(p.pid, 0);
        else if (action === "copy")
            ProcList.copyPid(p.pid);
    }

    function runAction(action) {
        tab.runActionOn(tab.menuProc, action, true);
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.dp(8)

        // ── Верхний тулбар (Windows 11 Processes Toolbar) ──────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(6)

            // Поле поиска
            TextField {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Theme.dp(248)
                variant: "search"
                icon: "search"
                placeholder: "Поиск по имени, PID, команде или пользователю…"
                onTextChanged: tab.query = text
            }

            // Чипы фильтра категорий: Все / Приложения / Фоновые
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.dp(4)

                Chip {
                    size: "sm"
                    label: "Все"
                    selected: tab.categoryFilter === "all"
                    onClicked: tab.categoryFilter = "all"
                }
                Chip {
                    size: "sm"
                    icon: "window"
                    label: tab.appsCount > 0 ? "Приложения (" + tab.appsCount + ")" : "Приложения"
                    selected: tab.categoryFilter === "apps"
                    onClicked: tab.categoryFilter = "apps"
                }
                Chip {
                    size: "sm"
                    label: "Фоновые"
                    selected: tab.categoryFilter === "bg"
                    onClicked: tab.categoryFilter = "bg"
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 1
                height: Theme.dp(22)
                color: Theme.divider
            }

            // Переключатель Дерево / Список
            Chip {
                Layout.alignment: Qt.AlignVCenter
                size: "sm"
                kind: "assist"
                icon: tab.treeMode ? "account_tree" : "view_list"
                label: tab.treeMode ? "Дерево" : "Список"
                selected: tab.treeMode
                onClicked: tab.treeMode = !tab.treeMode
            }

            // Кнопка Пауза / Пуск обновления таблицы
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                size: "s"
                variant: ProcList.paused ? "filled" : "tonal"
                icon: ProcList.paused ? "play_arrow" : "pause"
                tooltip: ProcList.paused ? "Возобновить обновление" : "Пауза обновления"
                onClicked: ProcList.paused = !ProcList.paused
            }

            Item { Layout.fillWidth: true }

            // Кнопка «К окну» (если у выбранного процесса открыто окно Umbriel)
            Button {
                Layout.alignment: Qt.AlignVCenter
                visible: tab.selectedProc !== null && tab.selectedProc.hasWindow && tab.selectedProc.winId !== ""
                size: "s"
                variant: "tonal"
                icon: "open_in_new"
                text: "К окну"
                onClicked: if (tab.selectedProc) tab.focusWindow(tab.selectedProc.winId)
            }

            // Акцентная кнопка «Снять задачу» (End task)
            Button {
                Layout.alignment: Qt.AlignVCenter
                size: "s"
                variant: "tonal"
                danger: true
                disabled: tab.selectedProc === null
                icon: "cancel"
                text: "Снять задачу"
                onClicked: if (tab.selectedProc) ProcList.term(tab.selectedProc.pid)
            }
        }

        // ── Шапка таблицы в стиле Windows 11 Task Manager (с итогами %) ─
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.dp(44)
            radius: Theme.rad(12)
            color: Theme.mLow
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.14)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: tab.cellPad
                anchors.rightMargin: tab.cellPad
                spacing: tab.cellGap

                // Колонка: Имя
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: tab.colName
                    Layout.fillHeight: true
                    Layout.topMargin: Theme.dp(3)
                    Layout.bottomMargin: Theme.dp(3)
                    radius: Theme.rad(8)
                    color: tab.sortBy === "name" ? Theme.alpha(Theme.primary, 0.1) : "transparent"

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        onClicked: tab.setSort("name")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(8)
                        anchors.rightMargin: Theme.dp(8)
                        spacing: 0

                        LText {
                            role: "labelSmall"
                            color: Theme.subtextDim
                            text: ProcList.paused ? "ПАУЗА · " + tab.rowCount + " проц." : tab.rowCount + " процессов"
                        }
                        LText {
                            role: "labelMedium"
                            weight: 640
                            color: tab.sortBy === "name" ? Theme.primary : Theme.text
                            text: "Имя" + tab.sortArrow("name")
                        }
                    }
                }

                // Колонка: Статус
                Rectangle {
                    Layout.preferredWidth: tab.colStatus
                    Layout.fillHeight: true
                    Layout.topMargin: Theme.dp(3)
                    Layout.bottomMargin: Theme.dp(3)
                    radius: Theme.rad(8)
                    color: tab.sortBy === "status" ? Theme.alpha(Theme.primary, 0.1) : "transparent"

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        onClicked: tab.setSort("status")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(6)
                        anchors.rightMargin: Theme.dp(6)
                        spacing: 0

                        LText {
                            role: "labelSmall"
                            color: Theme.subtextDim
                            text: "Состояние"
                        }
                        LText {
                            role: "labelMedium"
                            weight: 640
                            color: tab.sortBy === "status" ? Theme.primary : Theme.text
                            text: "Статус" + tab.sortArrow("status")
                        }
                    }
                }

                // Колонка: ЦП (с живым общим % в шапке)
                Rectangle {
                    Layout.preferredWidth: tab.colCpu
                    Layout.fillHeight: true
                    Layout.topMargin: Theme.dp(3)
                    Layout.bottomMargin: Theme.dp(3)
                    radius: Theme.rad(8)
                    color: tab.sortBy === "cpu" ? Theme.alpha(Theme.primary, 0.14) : "transparent"

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        onClicked: tab.setSort("cpu")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(6)
                        anchors.rightMargin: Theme.dp(6)
                        spacing: 0

                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelMedium"
                            tabular: true
                            weight: 700
                            color: SysStats.cpuPercent > 80 ? Theme.error
                                 : (SysStats.cpuPercent > 50 ? Theme.warning : Theme.primary)
                            text: SysStats.cpuPercent + "%"
                        }
                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelSmall"
                            weight: 640
                            color: tab.sortBy === "cpu" ? Theme.primary : Theme.subtext
                            text: "ЦП" + tab.sortArrow("cpu")
                        }
                    }
                }

                // Колонка: Память (с живым общим % в шапке)
                Rectangle {
                    Layout.preferredWidth: tab.colMem
                    Layout.fillHeight: true
                    Layout.topMargin: Theme.dp(3)
                    Layout.bottomMargin: Theme.dp(3)
                    radius: Theme.rad(8)
                    color: tab.sortBy === "mem" ? Theme.alpha(Theme.primary, 0.14) : "transparent"

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        onClicked: tab.setSort("mem")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(6)
                        anchors.rightMargin: Theme.dp(6)
                        spacing: 0

                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelMedium"
                            tabular: true
                            weight: 700
                            color: SysStats.memPct > 0.85 ? Theme.error
                                 : (SysStats.memPct > 0.70 ? Theme.warning : Theme.primary)
                            text: Math.round(SysStats.memPct * 100) + "%"
                        }
                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelSmall"
                            weight: 640
                            color: tab.sortBy === "mem" ? Theme.primary : Theme.subtext
                            text: "Память" + tab.sortArrow("mem")
                        }
                    }
                }

                // Колонка: Потоки (nlwp)
                Rectangle {
                    Layout.preferredWidth: tab.colThreads
                    Layout.fillHeight: true
                    Layout.topMargin: Theme.dp(3)
                    Layout.bottomMargin: Theme.dp(3)
                    radius: Theme.rad(8)
                    color: tab.sortBy === "threads" ? Theme.alpha(Theme.primary, 0.14) : "transparent"

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        onClicked: tab.setSort("threads")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(6)
                        anchors.rightMargin: Theme.dp(6)
                        spacing: 0

                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelSmall"
                            tabular: true
                            color: Theme.subtextDim
                            text: SysStats.cpuThreadsTotal > 0 ? String(SysStats.cpuThreadsTotal) : "NLWP"
                        }
                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelSmall"
                            weight: 640
                            color: tab.sortBy === "threads" ? Theme.primary : Theme.subtext
                            text: "Потоки" + tab.sortArrow("threads")
                        }
                    }
                }

                // Колонка: PID / Nice
                Rectangle {
                    Layout.preferredWidth: tab.colPidNice
                    Layout.fillHeight: true
                    Layout.topMargin: Theme.dp(3)
                    Layout.bottomMargin: Theme.dp(3)
                    radius: Theme.rad(8)
                    color: tab.sortBy === "pid" ? Theme.alpha(Theme.primary, 0.14) : "transparent"

                    StateLayer {
                        radius: parent.radius
                        tint: Theme.text
                        onClicked: tab.setSort("pid")
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(6)
                        anchors.rightMargin: Theme.dp(6)
                        spacing: 0

                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelSmall"
                            color: Theme.subtextDim
                            text: "ИД / Приор."
                        }
                        LText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            role: "labelSmall"
                            weight: 640
                            color: tab.sortBy === "pid" ? Theme.primary : Theme.subtext
                            text: "PID / Nice" + tab.sortArrow("pid")
                        }
                    }
                }
            }
        }

        // ── Список процессов с тепловой картой (Heat-Map) ──────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Theme.dp(200),
                Math.min(Theme.dp(560), tab.screenAvailHeight * 0.56 - Theme.dp(110)))

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: processModel

                delegate: Item {
                    id: rowItem

                    required property var pid
                    required property var ppid
                    required property var ni
                    required property var threads
                    required property var cpu
                    required property var mem
                    required property var rss
                    required property var stat
                    required property var state
                    required property var comm
                    required property var args
                    required property var name
                    required property var user
                    required property var depth
                    required property var hasChildren
                    required property var childCount
                    required property var expanded
                    required property var hasWindow
                    required property var winId
                    required property var winTitle
                    required property var iconPath
                    required property int index

                    readonly property var proc: ({
                        pid: Number(rowItem.pid),
                        ppid: Number(rowItem.ppid),
                        ni: Number(rowItem.ni),
                        threads: Number(rowItem.threads),
                        cpu: Number(rowItem.cpu),
                        mem: Number(rowItem.mem),
                        rss: Number(rowItem.rss),
                        stat: rowItem.stat,
                        state: rowItem.state,
                        comm: rowItem.comm,
                        args: rowItem.args,
                        name: rowItem.name,
                        user: rowItem.user,
                        hasWindow: Boolean(rowItem.hasWindow),
                        winId: String(rowItem.winId || "")
                    })
                    readonly property bool selected: tab.selectedPid === Number(rowItem.pid)

                    // Нормированные 0..1 значения для тепловой карты ячеек ЦП и Памяти
                    readonly property real cpuHeatNorm: Math.min(1, Number(rowItem.cpu) / Math.max(100, (SysStats.cores || 4) * 50))
                    readonly property real memHeatNorm: Math.min(1, Number(rowItem.mem) / 25)

                    width: listView.width
                    height: Theme.dp(40)

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: Theme.dp(1)
                        anchors.bottomMargin: Theme.dp(1)
                        radius: Theme.rad(10)
                        color: rowItem.selected ? Theme.secondaryContainer : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.durFastEffects }
                        }

                        StateLayer {
                            id: rowArea
                            radius: Theme.rad(10)
                            tint: rowItem.selected ? Theme.fgSecondaryContainer : Theme.text
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                tab.selectedPid = Number(rowItem.pid);
                                if (mouse.button === Qt.RightButton) {
                                    const p = rowArea.mapToItem(tab, mouse.x, mouse.y);
                                    tab.openMenu(rowItem.proc, p.x, p.y);
                                }
                            }
                            onDoubleClicked: {
                                if (rowItem.hasChildren && tab.treeMode)
                                    tab.toggleExpanded(Number(rowItem.pid));
                                else if (rowItem.hasWindow && rowItem.winId !== "")
                                    tab.focusWindow(String(rowItem.winId));
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: tab.cellPad
                        anchors.rightMargin: tab.cellPad
                        spacing: tab.cellGap

                        // ── Ячейка Имя: отступ дерева + шеврон + иконка + имя + бейдж детей + команда
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: tab.colName
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.dp(6)

                            // Шеврон дерева
                            Item {
                                visible: tab.treeMode
                                Layout.preferredWidth: Theme.dp(18)
                                Layout.preferredHeight: Theme.dp(24)
                                Layout.leftMargin: Theme.dp(Math.min(Number(rowItem.depth), 5) * 14)

                                Icon {
                                    anchors.centerIn: parent
                                    visible: Boolean(rowItem.hasChildren)
                                    name: rowItem.expanded ? "expand_more" : "chevron_right"
                                    size: Theme.dp(16)
                                    color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: Boolean(rowItem.hasChildren)
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        tab.selectedPid = Number(rowItem.pid);
                                        tab.toggleExpanded(Number(rowItem.pid));
                                    }
                                }
                            }

                            // Иконка процесса (системная иконка приложения или M3 символ)
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: Theme.dp(26)
                                implicitHeight: Theme.dp(26)
                                radius: Theme.rad(7)
                                color: rowItem.selected
                                    ? Theme.alpha(Theme.primary, 0.22)
                                    : (rowItem.hasWindow ? Theme.alpha(Theme.primaryContainer, 0.65) : Theme.bgTrack)

                                AppIcon {
                                    anchors.centerIn: parent
                                    visible: String(rowItem.iconPath) !== ""
                                    source: String(rowItem.iconPath)
                                    size: Theme.dp(18)
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    visible: String(rowItem.iconPath) === ""
                                    name: rowItem.hasWindow ? "window"
                                        : (rowItem.user === "root" ? "settings_applications" : "terminal")
                                    size: Theme.dp(15)
                                    color: rowItem.hasWindow ? Theme.primary : Theme.subtext
                                }
                            }

                            // Имя + бейдж дочерних процессов + превью команды
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.dp(6)

                                    LText {
                                        Layout.maximumWidth: Theme.dp(185)
                                        role: "titleSmall"
                                        color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.text
                                        text: String(rowItem.name)
                                        elide: Text.ElideRight
                                    }

                                    // Бейдж количества дочерних процессов
                                    Rectangle {
                                        visible: Boolean(rowItem.hasChildren) && Number(rowItem.childCount) > 0
                                        implicitHeight: Theme.dp(16)
                                        implicitWidth: childCntTxt.implicitWidth + Theme.dp(8)
                                        radius: Theme.dp(8)
                                        color: rowItem.selected ? Theme.alpha(Theme.primary, 0.25) : Theme.mHighest

                                        LText {
                                            id: childCntTxt
                                            anchors.centerIn: parent
                                            role: "labelSmall"
                                            tabular: true
                                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                                            text: String(rowItem.childCount)
                                        }
                                    }

                                    LText {
                                        Layout.fillWidth: true
                                        role: "bodySmall"
                                        color: rowItem.selected ? Theme.alpha(Theme.fgSecondaryContainer, 0.75) : Theme.subtextDim
                                        text: rowItem.winTitle !== "" ? rowItem.winTitle : String(rowItem.args)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // ── Ячейка Статус (Активно / Сон / Остановлен / Окно)
                        Item {
                            Layout.preferredWidth: tab.colStatus
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                implicitHeight: Theme.dp(22)
                                implicitWidth: Math.min(parent.width - Theme.dp(4), statusRow.implicitWidth + Theme.dp(12))
                                radius: Theme.dp(7)
                                color: rowItem.hasWindow ? Theme.alpha(Theme.primaryContainer, 0.75)
                                     : (rowItem.state === "R" ? Theme.alpha(Theme.success, 0.18)
                                     : (rowItem.state === "T" ? Theme.alpha(Theme.warning, 0.22)
                                     : (rowItem.state === "Z" ? Theme.alpha(Theme.errorContainer, 0.5) : Theme.bgTrack)))

                                RowLayout {
                                    id: statusRow
                                    anchors.centerIn: parent
                                    spacing: Theme.dp(4)

                                    Rectangle {
                                        width: Theme.dp(6)
                                        height: Theme.dp(6)
                                        radius: Theme.dp(3)
                                        color: rowItem.hasWindow ? Theme.primary
                                             : (rowItem.state === "R" ? Theme.success
                                             : (rowItem.state === "T" ? Theme.warning
                                             : (rowItem.state === "Z" ? Theme.error : Theme.subtextDim)))
                                    }

                                    LText {
                                        role: "labelSmall"
                                        color: rowItem.hasWindow ? Theme.fgPrimaryContainer
                                             : (rowItem.state === "R" ? Theme.success
                                             : (rowItem.state === "T" ? Theme.warning : Theme.subtext))
                                        text: tab.stateLabel(rowItem.state, Boolean(rowItem.hasWindow))
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // ── Ячейка ЦП (Windows Heat-Map tint) ─────────
                        Rectangle {
                            Layout.preferredWidth: tab.colCpu
                            Layout.fillHeight: true
                            Layout.topMargin: Theme.dp(2)
                            Layout.bottomMargin: Theme.dp(2)
                            radius: Theme.rad(7)
                            color: tab.heatColor(rowItem.cpuHeatNorm, rowItem.selected)

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(8)
                                role: "bodySmall"
                                weight: Number(rowItem.cpu) >= 10 ? 650 : 480
                                tabular: true
                                color: rowItem.selected ? Theme.fgSecondaryContainer
                                     : (Number(rowItem.cpu) > 50 ? Theme.error
                                     : (Number(rowItem.cpu) > 20 ? Theme.warning : Theme.text))
                                text: Number(rowItem.cpu).toFixed(1) + "%"
                            }
                        }

                        // ── Ячейка Память (Windows Heat-Map tint + МБ/ГБ)
                        Rectangle {
                            Layout.preferredWidth: tab.colMem
                            Layout.fillHeight: true
                            Layout.topMargin: Theme.dp(2)
                            Layout.bottomMargin: Theme.dp(2)
                            radius: Theme.rad(7)
                            color: tab.heatColor(rowItem.memHeatNorm, rowItem.selected)

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(8)
                                role: "bodySmall"
                                weight: Number(rowItem.mem) >= 5 ? 620 : 460
                                tabular: true
                                color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.text
                                text: tab.fmtMemRss(Number(rowItem.rss))
                            }
                        }

                        // ── Ячейка Потоки (nlwp) ──────────────────────
                        LText {
                            Layout.preferredWidth: tab.colThreads
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            role: "bodySmall"
                            tabular: true
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            text: String(rowItem.threads)
                        }

                        // ── Ячейка PID / Nice ─────────────────────────
                        LText {
                            Layout.preferredWidth: tab.colPidNice
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            role: "bodySmall"
                            tabular: true
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            text: Number(rowItem.ni) !== 0
                                ? String(rowItem.pid) + " (" + (Number(rowItem.ni) > 0 ? "+" : "") + String(rowItem.ni) + ")"
                                : String(rowItem.pid)
                        }
                    }
                }
            }

            LText {
                anchors.centerIn: parent
                visible: listView.count === 0 && !ProcList.loading
                role: "bodyMedium"
                color: Theme.subtext
                text: tab.query.trim() !== "" ? "Ничего не найдено" : "Нет процессов в выбранной категории"
            }
        }

        // ── Нижняя панель деталей выбранного процесса и быстрых действий
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: tab.selectedProc !== null ? Theme.dp(62) : Theme.dp(34)
            radius: Theme.rad(12)
            color: Theme.mHigh
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.16)

            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.durFastSpatial; easing.type: Easing.OutCubic }
            }

            // Когда процесс не выбран — краткая подсказка
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(12)
                anchors.rightMargin: Theme.dp(12)
                visible: tab.selectedProc === null
                spacing: Theme.dp(8)

                Icon {
                    name: "info"
                    size: Theme.dp(16)
                    color: Theme.subtext
                }
                LText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    color: Theme.subtext
                    text: "Выберите процесс для просмотра командной строки, родительского PID, RSS и управления приоритетом"
                    elide: Text.ElideRight
                }
                LText {
                    role: "labelSmall"
                    tabular: true
                    color: Theme.subtextDim
                    text: "Всего: " + ProcList.totalCount + " · Потоков: " + SysStats.cpuThreadsTotal
                }
            }

            // Когда процесс выбран — полная строка состояния + кнопки действий
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(12)
                anchors.rightMargin: Theme.dp(10)
                anchors.topMargin: Theme.dp(6)
                anchors.bottomMargin: Theme.dp(6)
                visible: tab.selectedProc !== null
                spacing: Theme.dp(4)

                // Верхний ряд: метаданные + быстрые кнопки
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(8)

                    LText {
                        role: "labelLarge"
                        weight: 660
                        color: Theme.primary
                        text: tab.selectedProc ? tab.selectedProc.name : ""
                    }

                    LText {
                        Layout.fillWidth: true
                        role: "labelSmall"
                        tabular: true
                        color: Theme.subtext
                        elide: Text.ElideRight
                        text: tab.selectedProc
                            ? ("PID: " + tab.selectedProc.pid
                               + "  ·  PPID: " + tab.selectedProc.ppid
                               + "  ·  Польз.: " + tab.selectedProc.user
                               + "  ·  Потоки: " + tab.selectedProc.threads
                               + "  ·  RSS: " + tab.fmtMemRss(tab.selectedProc.rss) + " (" + Number(tab.selectedProc.mem).toFixed(1) + "%)"
                               + "  ·  Nice: " + tab.selectedProc.ni
                               + "  ·  Сост.: " + tab.selectedProc.stat)
                            : ""
                    }

                    // Быстрые кнопки действий
                    RowLayout {
                        spacing: Theme.dp(4)

                        Button {
                            size: "xs"
                            variant: "tonal"
                            danger: true
                            icon: "do_not_disturb_on"
                            text: "TERM"
                            onClicked: if (tab.selectedProc) ProcList.term(tab.selectedProc.pid)
                        }
                        Button {
                            size: "xs"
                            variant: "filled"
                            danger: true
                            icon: "error"
                            text: "KILL"
                            onClicked: if (tab.selectedProc) ProcList.kill9(tab.selectedProc.pid)
                        }
                        Button {
                            size: "xs"
                            variant: "tonal"
                            icon: tab.selectedProc && tab.selectedProc.state === "T" ? "play_arrow" : "pause"
                            text: tab.selectedProc && tab.selectedProc.state === "T" ? "Пуск" : "Стоп"
                            onClicked: {
                                if (!tab.selectedProc) return;
                                if (tab.selectedProc.state === "T")
                                    ProcList.cont(tab.selectedProc.pid);
                                else
                                    ProcList.stop(tab.selectedProc.pid);
                            }
                        }
                        Button {
                            size: "xs"
                            variant: "outlined"
                            text: "Nice −5"
                            onClicked: if (tab.selectedProc) ProcList.renice(tab.selectedProc.pid, tab.selectedProc.ni - 5)
                        }
                        Button {
                            size: "xs"
                            variant: "outlined"
                            text: "Nice +5"
                            onClicked: if (tab.selectedProc) ProcList.renice(tab.selectedProc.pid, tab.selectedProc.ni + 5)
                        }
                        IconButton {
                            size: "xs"
                            variant: "tonal"
                            icon: "content_copy"
                            tooltip: "Копировать PID"
                            onClicked: if (tab.selectedProc) ProcList.copyPid(tab.selectedProc.pid)
                        }
                    }
                }

                // Нижний ряд: полная командная строка (args)
                LText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    mono: true
                    color: Theme.subtextDim
                    elide: Text.ElideMiddle
                    text: tab.selectedProc ? tab.selectedProc.args : ""
                }
            }
        }
    }

    // ── Контекстное меню (правый клик по строке) ──────────────────────
    Item {
        id: menuLayer
        anchors.fill: parent
        visible: tab.menuOpen
        z: 100

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: tab.closeMenu()
        }

        Rectangle {
            id: menuRect
            x: tab.menuX
            y: tab.menuY
            width: tab.menuW
            height: menuCol.implicitHeight + Theme.dp(10)
            radius: Theme.radiusXl
            color: Theme.mHigh
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.2)

            Column {
                id: menuCol
                anchors.fill: parent
                anchors.margins: Theme.dp(5)
                spacing: 0

                MenuRow {
                    visible: tab.menuProc !== null && Boolean(tab.menuProc.hasWindow) && String(tab.menuProc.winId || "") !== ""
                    icon: "open_in_new"
                    label: "Перейти к окну"
                    onActivated: {
                        const wid = tab.menuProc ? String(tab.menuProc.winId || "") : "";
                        tab.closeMenu();
                        tab.focusWindow(wid);
                    }
                }
                MenuRow {
                    icon: "do_not_disturb_on"
                    confirmAction: "term"
                    label: tab.armedAction === "term" && tab.menuProc
                        && tab.armedPid === tab.menuProc.pid ? "Ещё раз: снять задачу" : "Снять задачу (TERM)"
                    danger: true
                    onActivated: tab.runAction("term")
                }
                MenuRow {
                    icon: "error"
                    confirmAction: "kill9"
                    label: tab.armedAction === "kill9" && tab.menuProc
                        && tab.armedPid === tab.menuProc.pid ? "Ещё раз: убить" : "Убить процесс (KILL)"
                    danger: true
                    onActivated: tab.runAction("kill9")
                }
                MenuRow {
                    icon: "pause"
                    label: "Приостановить (STOP)"
                    onActivated: tab.runAction("stop")
                }
                MenuRow {
                    icon: "play_arrow"
                    label: "Возобновить (CONT)"
                    onActivated: tab.runAction("cont")
                }

                Item {
                    width: parent.width
                    implicitHeight: Theme.dp(8)
                }

                MenuRow {
                    icon: "arrow_upward"
                    label: "Приоритет +5 (ниже)"
                    onActivated: tab.runAction("niceUp")
                }
                MenuRow {
                    icon: "arrow_downward"
                    label: "Приоритет −5 (выше)"
                    onActivated: tab.runAction("niceDown")
                }
                MenuRow {
                    icon: "restart_alt"
                    label: "Сбросить приоритет (0)"
                    onActivated: tab.runAction("niceReset")
                }
                MenuRow {
                    icon: "content_copy"
                    label: "Копировать PID"
                    onActivated: tab.runAction("copy")
                }
            }
        }
    }

    component MenuRow: Item {
        id: mi

        property string icon: ""
        property string label: ""
        property bool danger: false
        property string confirmAction: ""

        signal activated()

        implicitWidth: tab.menuW - Theme.dp(10)
        implicitHeight: visible ? Theme.dp(36) : 0

        Rectangle {
            anchors.fill: parent
            radius: Theme.rad(12)
            color: mi.danger && miArea.containsMouse ? Theme.a(Theme.error, 0.12) : "transparent"

            StateLayer {
                id: miArea
                radius: Theme.rad(12)
                tint: mi.danger ? Theme.error : Theme.text
                onClicked: mi.activated()
                onContainsMouseChanged: {
                    if (!miArea.containsMouse && mi.confirmAction !== ""
                            && tab.armedAction === mi.confirmAction) {
                        tab.armedAction = "";
                        tab.armedPid = -1;
                        disarmTimer.stop();
                    }
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(10)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: mi.icon
                size: Theme.dp(18)
                color: mi.danger ? Theme.error : Theme.text
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelLarge"
                color: mi.danger ? Theme.error : Theme.text
                text: mi.label
            }
        }
    }
}
