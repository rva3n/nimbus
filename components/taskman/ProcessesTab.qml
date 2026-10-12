pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Диспетчер»: поиск, таблица процессов (ProcList обновляет ps
// каждые 2 с) и контекстное меню действий по правому клику на строке.
// Строки — в языке Lucid: высота 42, tabular-цифры, StateLayer-ховер и
// выбранная строка secondaryContainer; меню — размытая карточка radiusXl.
Item {
    id: tab

    property var shell: null
    // выбранный процесс: pid переживает перерисовки списка
    property int selectedPid: -1
    // сортировка списка и раскрытые в дереве узлы (ключ — строка pid)
    property string sortBy: "cpu"
    property var expanded: ({})
    // плоское дерево, построенное rebuild(): [{proc, depth, hasChildren, expanded}]
    property var model: []
    // порядок строк между обновлениями: pid (строка) → индекс в прошлом out;
    // пока не сброшен setSort(), соседи не пересортировываются при refresh
    property var _order: ({})
    // всего процессов после фильтра (не только видимых в дереве)
    property int rowCount: 0
    // контекстное меню: процесс и точка открытия
    property var menuProc: null
    property real menuX: 0
    property real menuY: 0
    property bool menuOpen: false

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    // геометрия колонок таблицы — общая для шапки и строк
    readonly property int cellPad: Theme.dp(10)
    readonly property int cellGap: Theme.dp(8)
    readonly property int colPid: Theme.dp(56)
    readonly property int colUser: Theme.dp(90)
    readonly property int colCpu: Theme.dp(60)
    readonly property int colMem: Theme.dp(70)
    readonly property int colNi: Theme.dp(36)
    readonly property int colStat: Theme.dp(44)
    readonly property int colName: Theme.dp(170)
    readonly property int menuW: Theme.dp(216)

    property string query: ""

    // меню не должно висеть после ухода с вкладки
    onVisibleChanged: if (!tab.visible) tab.closeMenu()

    // любые изменения фильтра или сортировки — сразу пересобрать дерево
    onQueryChanged: tab.rebuild()
    onSortByChanged: tab.rebuild()

    // дерево перестраиваем один раз за цикл — по завершении ps
    Connections {
        target: ProcList

        function onLoadingChanged() {
            if (!ProcList.loading && ProcList.items.length > 0)
                tab.rebuild();
        }
    }

    // сравнение соседей по выбранному полю
    function _cmp(a, b) {
        if (tab.sortBy === "mem")
            return b.mem - a.mem;
        if (tab.sortBy === "name")
            return String(a.name).localeCompare(String(b.name), "ru");
        if (tab.sortBy === "pid")
            return a.pid - b.pid;
        return b.cpu - a.cpu;
    }

    // перестройка плоского дерева из ProcList.items: фильтр → children по ppid →
    // сортировка соседей → DFS-разворот с учётом раскрытых узлов
    function rebuild() {
        const list = ProcList.items || [];
        const q = tab.query.trim().toLowerCase();
        const matched = [];
        for (const p of list) {
            if (q === "") {
                matched.push(p);
                continue;
            }
            const pid = String(p.pid);
            if (String(p.name).toLowerCase().indexOf(q) !== -1
                    || String(p.args).toLowerCase().indexOf(q) !== -1
                    || String(p.user).toLowerCase().indexOf(q) !== -1
                    || pid.indexOf(q) === 0)
                matched.push(p);
        }

        // ppid==pid или родитель не прошёл фильтр → узел становится корнем
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
        // для сортировки по cpu/mem берём максимум по поддереву: ветка с самым
        // горячим процессом всплывает наверх (в дереве «своё» значение родителя
        // обычно ноль и ничего не сортирует)
        const subMax = {};
        function _max(p) {
            let m = tab.sortBy === "mem" ? p.mem : p.cpu;
            for (const c of (children[String(p.pid)] || []))
                m = Math.max(m, _max(c));
            subMax[String(p.pid)] = m;
            return m;
        }
        for (const r of roots)
            _max(r);
        const cmp = (a, b) => {
            // стабильный порядок между обновлениями: если pid уже был в прошлой
            // раскладке — сохраняем прежний относительный порядок; новый pid
            // уходит после известных
            const oa = tab._order[String(a.pid)];
            const ob = tab._order[String(b.pid)];
            const ha = oa !== undefined;
            const hb = ob !== undefined;
            if (ha && hb) {
                if (oa !== ob)
                    return oa - ob;
            } else if (ha !== hb) {
                return ha ? -1 : 1;
            }
            // новых/неизвестных сортируем по метрике
            if (tab.sortBy === "cpu" || tab.sortBy === "mem") {
                const d = (subMax[String(b.pid)] || 0) - (subMax[String(a.pid)] || 0);
                if (d !== 0) return d;
            }
            return tab._cmp(a, b);
        };
        roots.sort(cmp);
        for (const k in children)
            children[k].sort(cmp);

        const out = [];
        const walk = (p, depth) => {
            const kids = children[String(p.pid)] || [];
            const ex = tab.expanded[String(p.pid)] !== false;
            out.push({
                proc: p,
                depth: depth,
                hasChildren: kids.length > 0,
                expanded: ex
            });
            if (ex) {
                for (const c of kids)
                    walk(c, depth + 1);
            }
        };
        for (const r of roots)
            walk(r, 0);

        // не теряем прокрутку при смене модели
        const savedY = listView.contentY;
        tab.model = out;
        tab.rowCount = matched.length;
        // запоминаем раскладку для следующего refresh (стабильный порядок)
        const order = {};
        for (let i = 0; i < out.length; i++)
            order[String(out[i].proc.pid)] = i;
        tab._order = order;
        // синхронно восстанавливаем прокрутку, чтобы не мигнуть верхом кадра
        listView.contentY = savedY;
        Qt.callLater(function() {
            listView.contentY = Math.min(savedY, Math.max(0, listView.contentHeight - listView.height));
        });
    }

    // ручная сортировка: сбрасываем замороженный порядок и переранжируем один раз
    function setSort(k) {
        tab._order = ({});
        tab.sortBy = k;
        tab.rebuild();
    }

    function toggleExpanded(pid) {
        const k = String(pid);
        tab.expanded[k] = !(tab.expanded[k] !== false);
        tab.rebuild();
    }

    // склонение: 1 процесс, 2 процесса, 5 процессов
    function procWord(n) {
        const d = n % 10, dd = n % 100;
        if (d === 1 && dd !== 11)
            return "процесс";
        if (d >= 2 && d <= 4 && (dd < 10 || dd >= 20))
            return "процесса";
        return "процессов";
    }

    // цвет загрузки ЦП: высокая — error, заметная — warning
    function cpuColor(v) {
        if (v > 50)
            return Theme.error;
        if (v > 20)
            return Theme.warning;
        return Theme.text;
    }

    function openMenu(proc, px, py) {
        tab.menuProc = proc;
        // прижимаем попап к границам вкладки
        tab.menuX = Math.max(Theme.dp(6), Math.min(px, tab.width - menuRect.width - Theme.dp(6)));
        tab.menuY = Math.max(Theme.dp(6), Math.min(py, tab.height - menuRect.height - Theme.dp(6)));
        tab.menuOpen = true;
    }

    function closeMenu() {
        tab.menuOpen = false;
        tab.menuProc = null;
    }

    // действие меню над запомненным процессом
    function runAction(action) {
        const p = tab.menuProc;
        tab.closeMenu();
        if (!p)
            return;
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

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.dp(10)

        // ── Тулбар: поиск слева, счётчик и статус справа ──────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            TextField {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Theme.dp(280)
                variant: "filled"
                icon: "search"
                placeholder: "Поиск по имени, команде или PID"
                onTextChanged: tab.query = text
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.dp(6)

                Chip {
                    label: "CPU"
                    selected: tab.sortBy === "cpu"
                    onClicked: tab.setSort("cpu")
                }
                Chip {
                    label: "Память"
                    selected: tab.sortBy === "mem"
                    onClicked: tab.setSort("mem")
                }
                Chip {
                    label: "Имя"
                    selected: tab.sortBy === "name"
                    onClicked: tab.setSort("name")
                }
                Chip {
                    label: "PID"
                    selected: tab.sortBy === "pid"
                    onClicked: tab.setSort("pid")
                }
            }

            Item { Layout.fillWidth: true }

            LText {
                Layout.alignment: Qt.AlignVCenter
                role: "labelSmall"
                tabular: true
                color: Theme.subtext
                text: tab.rowCount + " " + tab.procWord(tab.rowCount)
            }

            LText {
                Layout.alignment: Qt.AlignVCenter
                visible: ProcList.loading
                role: "labelSmall"
                color: Theme.subtextDim
                text: "обновление…"
            }
        }

        // ── Шапка таблицы: не скроллится, отступы как у строк ─────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: tab.cellPad
            Layout.rightMargin: tab.cellPad
            spacing: tab.cellGap

            Item { // место под шеврон в строках дерева
                Layout.preferredWidth: Theme.dp(16)
                Layout.leftMargin: Theme.dp(4)
            }

            LText {
                Layout.preferredWidth: tab.colName
                Layout.alignment: Qt.AlignVCenter
                role: "labelSmall"
                color: Theme.subtext
                text: "Процесс"
                elide: Text.ElideRight
            }

            LText {
                Layout.fillWidth: true
                Layout.minimumWidth: Theme.dp(180)
                Layout.alignment: Qt.AlignVCenter
                role: "labelSmall"
                color: Theme.subtext
                text: "Команда"
                elide: Text.ElideRight
            }

            LText {
                Layout.preferredWidth: tab.colPid
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                role: "labelSmall"
                color: Theme.subtext
                text: "PID"
            }

            LText {
                Layout.preferredWidth: tab.colUser
                Layout.alignment: Qt.AlignVCenter
                role: "labelSmall"
                color: Theme.subtext
                text: "Пользователь"
            }

            LText {
                Layout.preferredWidth: tab.colCpu
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                role: "labelSmall"
                color: Theme.subtext
                text: "ЦП %"
            }

            LText {
                Layout.preferredWidth: tab.colMem
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                role: "labelSmall"
                color: Theme.subtext
                text: "Память %"
            }

            LText {
                Layout.preferredWidth: tab.colNi
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                role: "labelSmall"
                color: Theme.subtext
                text: "NI"
            }

            LText {
                Layout.preferredWidth: tab.colStat
                Layout.alignment: Qt.AlignVCenter
                role: "labelSmall"
                color: Theme.subtext
                text: "Сост."
            }
        }

        // ── Список процессов (прокрутка колёсиком) ────────────────────
        Item {
            Layout.fillWidth: true
            // фиксированная высота: панель диспетчера ~810, без внешней прокрутки
            Layout.preferredHeight: Theme.dp(640)

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: tab.model

                delegate: Item {
                    id: rowItem

                    required property var modelData
                    required property int index

                    readonly property var proc: rowItem.modelData.proc
                    readonly property int depth: rowItem.modelData.depth
                    readonly property bool hasChildren: rowItem.modelData.hasChildren
                    readonly property bool expanded: rowItem.modelData.expanded
                    readonly property bool selected: tab.selectedPid === rowItem.proc.pid

                    width: listView.width
                    height: Theme.dp(42)

                    Rectangle { // фон строки: выбор — secondaryContainer, иначе StateLayer-ховер
                        anchors.fill: parent
                        anchors.topMargin: Theme.dp(1)
                        anchors.bottomMargin: Theme.dp(1)
                        radius: Theme.rad(10)
                        color: rowItem.selected ? Theme.secondaryContainer : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.durDefaultEffects }
                        }

                        StateLayer {
                            id: rowArea
                            radius: Theme.rad(10)
                            tint: rowItem.selected ? Theme.fgSecondaryContainer : Theme.text
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                tab.selectedPid = rowItem.proc.pid;
                                if (mouse.button === Qt.RightButton) {
                                    // позиция меню — точка клика, переведённая во вкладку
                                    const p = rowArea.mapToItem(tab, mouse.x, mouse.y);
                                    tab.openMenu(rowItem.proc, p.x, p.y);
                                } else if (rowItem.hasChildren) {
                                    tab.toggleExpanded(rowItem.proc.pid);
                                }
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: tab.cellPad
                        anchors.rightMargin: tab.cellPad
                        spacing: tab.cellGap

                        Item { // шеврон дерева (пустое место у листьев)
                            Layout.preferredWidth: Theme.dp(16)
                            Layout.leftMargin: Theme.dp(4 + Math.min(rowItem.depth, 5) * 14)
                            Layout.alignment: Qt.AlignVCenter

                            Icon {
                                anchors.centerIn: parent
                                visible: rowItem.hasChildren
                                name: rowItem.expanded ? "expand_more" : "chevron_right"
                                size: Theme.dp(16)
                                color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            }
                        }

                        LText { // имя процесса
                            Layout.preferredWidth: tab.colName
                            Layout.alignment: Qt.AlignVCenter
                            role: "titleSmall"
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.text
                            text: rowItem.proc.name
                            elide: Text.ElideRight
                        }

                        LText { // полная команда — видно игру/путь, а не comm
                            Layout.fillWidth: true
                            Layout.minimumWidth: Theme.dp(180)
                            Layout.alignment: Qt.AlignVCenter
                            role: "bodySmall"
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtextDim
                            text: rowItem.proc.args
                            elide: Text.ElideRight
                        }

                        LText { // PID
                            Layout.preferredWidth: tab.colPid
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            role: "bodySmall"
                            tabular: true
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            text: String(rowItem.proc.pid)
                        }

                        LText { // пользователь
                            Layout.preferredWidth: tab.colUser
                            Layout.alignment: Qt.AlignVCenter
                            role: "bodySmall"
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            text: rowItem.proc.user
                            elide: Text.ElideRight
                        }

                        LText { // ЦП %
                            Layout.preferredWidth: tab.colCpu
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            role: "bodySmall"
                            tabular: true
                            color: rowItem.selected ? Theme.fgSecondaryContainer
                                                    : tab.cpuColor(rowItem.proc.cpu)
                            text: Number(rowItem.proc.cpu).toFixed(1)
                        }

                        LText { // память %
                            Layout.preferredWidth: tab.colMem
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            role: "bodySmall"
                            tabular: true
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            text: Number(rowItem.proc.mem).toFixed(1)
                        }

                        LText { // nice
                            Layout.preferredWidth: tab.colNi
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            role: "bodySmall"
                            tabular: true
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            text: String(rowItem.proc.ni)
                        }

                        LText { // состояние
                            Layout.preferredWidth: tab.colStat
                            Layout.alignment: Qt.AlignVCenter
                            role: "bodySmall"
                            color: rowItem.selected ? Theme.fgSecondaryContainer : Theme.subtext
                            text: rowItem.proc.stat
                        }
                    }
                }
            }

            LText { // пусто / ничего не найдено (во время обновления не мигаем)
                anchors.centerIn: parent
                visible: listView.count === 0 && !ProcList.loading
                role: "bodyMedium"
                color: Theme.subtext
                text: tab.query.trim() !== "" ? "Ничего не найдено" : "Нет процессов"
            }
        }
    }

    // ── Контекстное меню (правый клик по строке) ──────────────────────
    Item {
        id: menuLayer
        anchors.fill: parent
        visible: tab.menuOpen
        z: 100

        MouseArea { // клик вне меню — закрыть
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
            color: Theme.withBlur(Theme.mHigh)
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.2)

            Column {
                id: menuCol
                anchors.fill: parent
                anchors.margins: Theme.dp(5)
                spacing: 0

                MenuRow {
                    icon: "do_not_disturb_on"
                    label: "Остановить (TERM)"
                    danger: true
                    onActivated: tab.runAction("term")
                }
                MenuRow {
                    icon: "error"
                    label: "Убить (KILL)"
                    danger: true
                    onActivated: tab.runAction("kill9")
                }
                MenuRow {
                    icon: "pause"
                    label: "Пауза (STOP)"
                    onActivated: tab.runAction("stop")
                }
                MenuRow {
                    icon: "play_arrow"
                    label: "Продолжить (CONT)"
                    onActivated: tab.runAction("cont")
                }

                Item { // отбивка между группами
                    width: parent.width
                    implicitHeight: Theme.dp(9)
                }

                MenuRow {
                    icon: "arrow_upward"
                    label: "Приоритет +5"
                    onActivated: tab.runAction("niceUp")
                }
                MenuRow {
                    icon: "arrow_downward"
                    label: "Приоритет −5"
                    onActivated: tab.runAction("niceDown")
                }
                MenuRow {
                    icon: "restart_alt"
                    label: "Сбросить (0)"
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

    // строка контекстного меню: иконка 16 + подпись labelLarge, StateLayer-ховер
    component MenuRow: Item {
        id: mi

        property string icon: ""
        property string label: ""
        property bool danger: false

        signal activated()

        implicitWidth: tab.menuW - Theme.dp(10)
        implicitHeight: Theme.dp(38)

        Rectangle {
            anchors.fill: parent
            radius: Theme.rad(12)
            color: mi.danger && miArea.containsMouse ? Theme.a(Theme.error, 0.12) : "transparent"

            StateLayer {
                id: miArea
                radius: Theme.rad(12)
                tint: mi.danger ? Theme.error : Theme.text
                onClicked: mi.activated()
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
