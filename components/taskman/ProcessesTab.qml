pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Диспетчер»: поиск, таблица процессов (ProcList обновляет ps
// каждые 2 с) и контекстное меню действий по правому клику на строке.
Item {
    id: tab

    property var shell: null
    // выбранный процесс: pid переживает перерисовки списка
    property int selectedPid: -1
    // последний непустой срез ProcList; сам ProcList каждые 2 с на время
    // обновления обнуляет items — без «липкой» копии список сбрасывал бы
    // прокрутку вверх на каждом цикле
    property var rows: []
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
    readonly property int menuW: Theme.dp(208)

    // фильтр по имени и pid
    readonly property var filtered: {
        const q = tab.query.trim().toLowerCase();
        if (q === "")
            return tab.rows;
        const out = [];
        for (const p of tab.rows) {
            if (String(p.name).toLowerCase().indexOf(q) !== -1 || String(p.pid).indexOf(q) !== -1)
                out.push(p);
        }
        return out;
    }

    property string query: ""

    // меню не должно висеть после ухода с вкладки
    onVisibleChanged: if (!tab.visible) tab.closeMenu()

    // строки обновляем один раз за цикл — по завершении ps
    Connections {
        target: ProcList

        function onLoadingChanged() {
            if (!ProcList.loading && ProcList.items.length > 0)
                tab.rows = ProcList.items;
        }
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
        spacing: Theme.dp(8)

        // ── Тулбар: поиск слева, счётчик и статус справа ──────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            TextField {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Theme.dp(280)
                placeholder: "Поиск по имени или PID"
                onTextChanged: tab.query = text
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: tab.filtered.length + " " + tab.procWord(tab.filtered.length)
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: ProcList.loading
                text: "обновление…"
                color: Theme.subtextDim
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
            }
        }

        // ── Шапка таблицы: не скроллится, отступы как у строк ─────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: tab.cellPad
            Layout.rightMargin: tab.cellPad
            spacing: tab.cellGap

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: "Процесс"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
                elide: Text.ElideRight
            }

            Text {
                Layout.preferredWidth: tab.colPid
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: "PID"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
            }

            Text {
                Layout.preferredWidth: tab.colUser
                Layout.alignment: Qt.AlignVCenter
                text: "Пользователь"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
            }

            Text {
                Layout.preferredWidth: tab.colCpu
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: "ЦП %"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
            }

            Text {
                Layout.preferredWidth: tab.colMem
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: "Память %"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
            }

            Text {
                Layout.preferredWidth: tab.colNi
                Layout.alignment: Qt.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: "NI"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
            }

            Text {
                Layout.preferredWidth: tab.colStat
                Layout.alignment: Qt.AlignVCenter
                text: "Сост."
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
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
                model: tab.filtered

                delegate: Item {
                    id: rowItem

                    required property var modelData
                    required property int index

                    readonly property var proc: rowItem.modelData
                    readonly property bool selected: tab.selectedPid === rowItem.proc.pid

                    width: listView.width
                    height: Theme.dp(34)

                    Rectangle { // фон строки: hover / выбор
                        anchors.fill: parent
                        radius: Theme.radiusSm
                        color: rowItem.selected ? Theme.accentContainer
                             : (rowArea.containsMouse ? Theme.bgHover : "transparent")

                        Behavior on color {
                            ColorAnimation { duration: Theme.durQuick }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: tab.cellPad
                        anchors.rightMargin: tab.cellPad
                        spacing: tab.cellGap

                        Text { // имя процесса
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: rowItem.proc.name
                            color: rowItem.selected ? Theme.fgAccentContainer : Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("titleSmall")
                            font.weight: Theme.typeWeight("titleSmall")
                        }

                        Text { // PID
                            Layout.preferredWidth: tab.colPid
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(rowItem.proc.pid)
                            color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }

                        Text { // пользователь
                            Layout.preferredWidth: tab.colUser
                            Layout.alignment: Qt.AlignVCenter
                            text: rowItem.proc.user
                            color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtext
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }

                        Text { // ЦП %
                            Layout.preferredWidth: tab.colCpu
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: Number(rowItem.proc.cpu).toFixed(1)
                            color: rowItem.selected ? Theme.fgAccentContainer
                                                    : tab.cpuColor(rowItem.proc.cpu)
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }

                        Text { // память %
                            Layout.preferredWidth: tab.colMem
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: Number(rowItem.proc.mem).toFixed(1)
                            color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }

                        Text { // nice
                            Layout.preferredWidth: tab.colNi
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: String(rowItem.proc.ni)
                            color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }

                        Text { // состояние
                            Layout.preferredWidth: tab.colStat
                            Layout.alignment: Qt.AlignVCenter
                            text: rowItem.proc.stat
                            color: rowItem.selected ? Theme.fgAccentContainer : Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                            tab.selectedPid = rowItem.proc.pid;
                            if (mouse.button === Qt.RightButton) {
                                // позиция меню — точка клика, переведённая во вкладку
                                const p = rowArea.mapToItem(tab, mouse.x, mouse.y);
                                tab.openMenu(rowItem.proc, p.x, p.y);
                            }
                        }
                    }
                }
            }

            Text { // пусто / ничего не найдено (во время обновления не мигаем)
                anchors.centerIn: parent
                visible: listView.count === 0 && !ProcList.loading
                text: tab.query.trim() !== "" ? "Ничего не найдено" : "Нет процессов"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium")
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
            height: menuCol.implicitHeight + Theme.dp(8)
            radius: Theme.radiusMd
            color: Theme.mHigh
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)

            Column {
                id: menuCol
                anchors.fill: parent
                anchors.margins: Theme.dp(4)
                spacing: 0

                MenuRow {
                    icon: "do_not_disturb_on"
                    label: "Остановить (TERM)"
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

                Item { // разделитель между группами
                    width: parent.width
                    implicitHeight: Theme.dp(9)

                    Divider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        leftInset: Theme.dp(6)
                        rightInset: Theme.dp(6)
                    }
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

    // строка контекстного меню: иконка 16 + подпись labelLarge, hover bgHover
    component MenuRow: Item {
        id: mi

        property string icon: ""
        property string label: ""
        property bool danger: false

        signal activated()

        implicitWidth: tab.menuW - Theme.dp(8)
        implicitHeight: Theme.dp(36)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSm
            color: miArea.containsMouse ? Theme.bgHover : "transparent"

            Behavior on color {
                ColorAnimation { duration: Theme.durQuick }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(10)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: mi.icon
                size: Theme.dp(16)
                color: mi.danger ? Theme.error : Theme.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mi.label
                color: mi.danger ? Theme.error : Theme.text
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelLarge")
                font.weight: Theme.typeWeight("labelLarge")
            }
        }

        MouseArea {
            id: miArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mi.activated()
        }
    }
}
