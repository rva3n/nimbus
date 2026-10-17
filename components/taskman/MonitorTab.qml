pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Производительность» в стиле Windows 11 Task Manager (Material 3 Expressive):
// Слева — панель выбора ресурса (195dp) с 5 карточками и живыми мини-спарклайнами (Canvas):
//   ЦП, Память, Диск, Сеть, ГП.
// Справа — детальная панель: заголовок и модель устройства, 60-секундный график
// реального времени (или сетка логических процессоров для ЦП) и таблица телеметрии.
RowLayout {
    id: monitor

    property var shell: null
    // Выбранный раздел: "cpu" | "memory" | "disk" | "network" | "gpu"
    property string selectedResource: "cpu"
    // Режим графика ЦП: "overall" (Общий график) | "cores" (Логические процессоры)
    property string cpuChartMode: "overall"

    // Счетчик тиков для перерисовки графиков Canvas
    property int paintTick: 0

    Layout.fillWidth: true
    spacing: Theme.dp(12)

    Connections {
        target: SysStats

        function onCpuHistoryChanged() {
            monitor.paintTick = (monitor.paintTick + 1) % 100000;
            mainChartCanvas.requestPaint();
        }
    }

    onSelectedResourceChanged: mainChartCanvas.requestPaint()
    onCpuChartModeChanged: mainChartCanvas.requestPaint()

    // ── Цвета акцентов ресурсов (Windows 11 Performance style в палитре M3) ─
    function resourceColor(key) {
        if (key === "cpu") return Theme.primary;
        if (key === "memory") return Theme.tertiary;
        if (key === "disk") return Theme.success;
        if (key === "network") return Theme.warning;
        if (key === "gpu") return Theme.secondary;
        return Theme.primary;
    }

    // ── Отрисовка графика (Canvas: сетка + заливка 0.22 + линия 2dp) ────
    function drawChart(ctx, w, h, series1, col1, series2, col2, showGrid) {
        if (w <= 0 || h <= 0)
            return;
        ctx.clearRect(0, 0, w, h);

        if (showGrid) {
            ctx.strokeStyle = Theme.alpha(Theme.outline, 0.2);
            ctx.lineWidth = 1;
            const hRows = 4;
            for (let r = 1; r < hRows; r++) {
                const gy = Math.round((r / hRows) * h) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, gy);
                ctx.lineTo(w, gy);
                ctx.stroke();
            }
            const vCols = 6;
            for (let c = 1; c < vCols; c++) {
                const gx = Math.round((c / vCols) * w) + 0.5;
                ctx.beginPath();
                ctx.moveTo(gx, 0);
                ctx.lineTo(gx, h);
                ctx.stroke();
            }
        }

        function plotLine(pts, strokeCol, fillAlpha, dashed) {
            if (!pts || pts.length < 2)
                return;
            const n = pts.length;
            const padY = showGrid ? Theme.dp(3) : Theme.dp(2);
            const usableH = Math.max(2, h - padY * 2);

            // Заливка под кривой
            ctx.beginPath();
            ctx.moveTo(0, h);
            for (let i = 0; i < n; i++) {
                const v = Math.max(0, Math.min(1, isFinite(pts[i]) ? pts[i] : 0));
                const px = (i / (n - 1)) * w;
                const py = h - padY - v * usableH;
                ctx.lineTo(px, py);
            }
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = Theme.alpha(strokeCol, fillAlpha);
            ctx.fill();

            // Верхняя линия 2dp
            ctx.beginPath();
            if (ctx.setLineDash)
                ctx.setLineDash(dashed ? [Theme.dp(5), Theme.dp(4)] : []);
            for (let i = 0; i < n; i++) {
                const v = Math.max(0, Math.min(1, isFinite(pts[i]) ? pts[i] : 0));
                const px = (i / (n - 1)) * w;
                const py = h - padY - v * usableH;
                if (i === 0)
                    ctx.moveTo(px, py);
                else
                    ctx.lineTo(px, py);
            }
            ctx.strokeStyle = strokeCol;
            ctx.lineWidth = showGrid ? Theme.dp(2) : Theme.dp(1.5);
            ctx.lineJoin = "round";
            ctx.stroke();
            if (ctx.setLineDash)
                ctx.setLineDash([]);
        }

        if (series2 && series2.length >= 2)
            plotLine(series2, col2, 0.14, true);
        if (series1 && series1.length >= 2)
            plotLine(series1, col1, 0.22, false);
    }

    function fmtGhz(mhz) {
        if (!isFinite(mhz) || mhz <= 0)
            return "—";
        return (mhz / 1000).toFixed(2) + " ГГц";
    }

    function fmtLoad(v) {
        return (isFinite(v) ? v : 0).toFixed(2);
    }

    function tempTone(c, warnAt, errAt) {
        if (c >= errAt) return Theme.error;
        if (c >= warnAt) return Theme.warning;
        return Theme.text;
    }

    // Модель левой боковой панели (5 ресурсов)
    readonly property var sidebarResources: [
        {
            key: "cpu",
            title: "ЦП",
            icon: "memory",
            sub: SysStats.cpuPercent + "% · " + SysStats.cpuGhz + " ГГц",
            history: SysStats.cpuHistory
        },
        {
            key: "memory",
            title: "Память",
            icon: "storage",
            sub: SysStats.formatBytes(SysStats.memUsed) + " / " + SysStats.formatBytes(SysStats.memTotal) + " (" + Math.round(SysStats.memPct * 100) + "%)",
            history: SysStats.memHistory
        },
        {
            key: "disk",
            title: "Диск",
            icon: "hard_drive",
            sub: "↓ " + SysStats.formatRate(SysStats.diskReadRate) + " ↑ " + SysStats.formatRate(SysStats.diskWriteRate),
            history: SysStats.diskIoHistory
        },
        {
            key: "network",
            title: "Сеть",
            icon: "lan",
            sub: (SysStats.netIface || "Сеть") + " · ↓ " + SysStats.formatRate(SysStats.netRx),
            history: SysStats.netRxHistory
        },
        {
            key: "gpu",
            title: "ГП",
            icon: "developer_board",
            sub: SysStats.gpuAvailable ? (SysStats.gpuUsage + "% · " + (SysStats.gpuTemp > 0 ? SysStats.gpuTemp + "°C" : "Активен")) : "Н/Д",
            history: SysStats.gpuHistory
        }
    ]

    // Заголовок и имя модели для выбранного ресурса
    readonly property string activeTitle: {
        if (monitor.selectedResource === "cpu") return "ЦП";
        if (monitor.selectedResource === "memory") return "Память";
        if (monitor.selectedResource === "disk") return "Диск";
        if (monitor.selectedResource === "network") return "Сеть";
        return "Графический процессор";
    }

    readonly property string activeModelName: {
        if (monitor.selectedResource === "cpu")
            return SysStats.cpuModel || (SysStats.cores + " ядер");
        if (monitor.selectedResource === "memory")
            return SysStats.formatBytes(SysStats.memTotal) + " ОЗУ" + (SysStats.swapTotal > 0 ? " · Swap " + SysStats.formatBytes(SysStats.swapTotal) : "");
        if (monitor.selectedResource === "disk")
            return SysStats.disks.length > 0 && SysStats.disks[0].device
                ? (SysStats.disks[0].device + " (" + (SysStats.disks[0].fstype || "FS") + ")")
                : SysStats.formatBytes(SysStats.diskTotal);
        if (monitor.selectedResource === "network")
            return (SysStats.netIface || "Сетевой адаптер") + (SysStats.netIp ? " · " + SysStats.netIp : "");
        return SysStats.gpuName || "Видеоадаптер";
    }

    readonly property string chartLeftCaption: {
        if (monitor.selectedResource === "cpu")
            return monitor.cpuChartMode === "cores" ? "Загрузка по логическим процессорам" : "% использования";
        if (monitor.selectedResource === "memory")
            return "Использование памяти";
        if (monitor.selectedResource === "disk")
            return "Скорость обмена с диском (Чтение / Запись)";
        if (monitor.selectedResource === "network")
            return "Пропускная способность (Получение / Отправка)";
        return "% использования ядра ГП";
    }

    readonly property string chartRightScale: {
        if (monitor.selectedResource === "disk")
            return "Макс: " + SysStats.formatRate(SysStats.diskScaleMax);
        if (monitor.selectedResource === "network")
            return "Макс: " + SysStats.formatRate(SysStats.netScaleMax);
        return "100%";
    }

    // ════════════════════════════════════════════════════════════════════
    // 1. ЛЕВАЯ БОКОВАЯ ПАНЕЛЬ (195dp wide — 5 карточек со спарклайнами)
    // ════════════════════════════════════════════════════════════════════
    ColumnLayout {
        Layout.preferredWidth: Theme.dp(195)
        Layout.minimumWidth: Theme.dp(195)
        Layout.maximumWidth: Theme.dp(195)
        Layout.alignment: Qt.AlignTop
        spacing: Theme.dp(7)

        Repeater {
            model: monitor.sidebarResources

            delegate: Rectangle {
                id: navCard

                required property var modelData
                required property int index

                readonly property bool selected: monitor.selectedResource === navCard.modelData.key
                readonly property color accentCol: monitor.resourceColor(navCard.modelData.key)

                Layout.fillWidth: true
                implicitHeight: Theme.dp(82)
                radius: Theme.rad(14)
                color: navCard.selected ? Theme.secondaryContainer : Theme.mHigh
                border.width: navCard.selected ? 1.5 : 1
                border.color: navCard.selected ? navCard.accentCol : Theme.alpha(Theme.outline, 0.14)

                Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }

                StateLayer {
                    radius: navCard.radius
                    tint: navCard.selected ? Theme.fgSecondaryContainer : Theme.text
                    onClicked: monitor.selectedResource = navCard.modelData.key
                }

                // Акцентная полоска слева у выбранной карточки (как в Windows 11)
                Rectangle {
                    visible: navCard.selected
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.dp(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(3)
                    height: Theme.dp(34)
                    radius: Theme.dp(2)
                    color: navCard.accentCol
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.dp(12)
                    anchors.rightMargin: Theme.dp(10)
                    anchors.topMargin: Theme.dp(8)
                    anchors.bottomMargin: Theme.dp(8)
                    spacing: Theme.dp(4)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(6)

                        Icon {
                            name: navCard.modelData.icon
                            size: Theme.dp(16)
                            color: navCard.accentCol
                        }

                        LText {
                            Layout.fillWidth: true
                            role: "titleSmall"
                            weight: 650
                            color: navCard.selected ? Theme.fgSecondaryContainer : Theme.text
                            text: navCard.modelData.title
                            elide: Text.ElideRight
                        }
                    }

                    LText {
                        Layout.fillWidth: true
                        role: "labelSmall"
                        tabular: true
                        color: navCard.selected ? Theme.alpha(Theme.fgSecondaryContainer, 0.85) : Theme.subtext
                        text: navCard.modelData.sub
                        elide: Text.ElideRight
                    }

                    // Мини-спарклайн (Canvas)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.dp(26)
                        radius: Theme.rad(6)
                        color: Theme.alpha(Theme.mLowest, 0.45)
                        border.width: 1
                        border.color: Theme.alpha(navCard.accentCol, 0.25)
                        clip: true

                        Canvas {
                            id: sparkCanvas
                            anchors.fill: parent
                            property int tickRef: monitor.paintTick
                            onTickRefChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                monitor.drawChart(ctx, width, height, navCard.modelData.history, navCard.accentCol, null, "transparent", false);
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // 2. ПРАВАЯ ДЕТАЛЬНАЯ ПАНЕЛЬ (График 60с + Телеметрия в стиле Windows)
    // ════════════════════════════════════════════════════════════════════
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Theme.dp(10)

        // ── Верхняя шапка ресурса: Название слева, переключение вида и модель справа
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            LText {
                role: "headlineSmall"
                weight: 660
                color: Theme.text
                text: monitor.activeTitle
            }

            // Переключатель для ЦП: «Общий график» vs «Логические процессоры»
            RowLayout {
                visible: monitor.selectedResource === "cpu"
                Layout.leftMargin: Theme.dp(6)
                spacing: Theme.dp(5)

                Chip {
                    size: "sm"
                    icon: "show_chart"
                    label: "Общий график"
                    selected: monitor.cpuChartMode === "overall"
                    onClicked: monitor.cpuChartMode = "overall"
                }

                Chip {
                    size: "sm"
                    icon: "grid_view"
                    label: "Логические процессоры (" + (SysStats.cores || SysStats.coreHistories.length) + ")"
                    selected: monitor.cpuChartMode === "cores"
                    onClicked: monitor.cpuChartMode = "cores"
                }
            }

            Item { Layout.fillWidth: true }

            LText {
                Layout.maximumWidth: Theme.dp(340)
                horizontalAlignment: Text.AlignRight
                role: "bodyMedium"
                color: Theme.subtext
                text: monitor.activeModelName
                elide: Text.ElideRight
            }
        }

        // ── Карточка главного 60-секундного графика (или сетки ядер ЦП) ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.dp(218)
            radius: Theme.shapeLgInc
            color: Theme.mHigh
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.16)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.dp(12)
                spacing: Theme.dp(6)

                // Подписи над графиком: слева тип метрики + легенда, справа верхняя шкала
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(10)

                    LText {
                        role: "labelSmall"
                        color: Theme.subtext
                        text: monitor.chartLeftCaption
                    }

                    // Легенда двойных линий для Диска и Сети
                    RowLayout {
                        visible: monitor.selectedResource === "disk" || monitor.selectedResource === "network"
                        spacing: Theme.dp(10)

                        RowLayout {
                            spacing: Theme.dp(4)
                            Rectangle {
                                width: Theme.dp(10)
                                height: Theme.dp(3)
                                radius: 1
                                color: monitor.resourceColor(monitor.selectedResource)
                            }
                            LText {
                                role: "labelSmall"
                                color: Theme.subtext
                                text: monitor.selectedResource === "disk" ? "Чтение" : "Получение (RX)"
                            }
                        }

                        RowLayout {
                            spacing: Theme.dp(4)
                            Rectangle {
                                width: Theme.dp(10)
                                height: Theme.dp(3)
                                radius: 1
                                color: Theme.primary
                            }
                            LText {
                                role: "labelSmall"
                                color: Theme.subtext
                                text: monitor.selectedResource === "disk" ? "Запись" : "Отправка (TX)"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    LText {
                        role: "labelSmall"
                        tabular: true
                        color: Theme.subtext
                        text: monitor.chartRightScale
                    }
                }

                // A. Одиночный / двойной 60-секундный график
                Rectangle {
                    visible: !(monitor.selectedResource === "cpu" && monitor.cpuChartMode === "cores")
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.rad(10)
                    color: Theme.alpha(Theme.mLowest, 0.55)
                    border.width: 1
                    border.color: Theme.alpha(monitor.resourceColor(monitor.selectedResource), 0.35)
                    clip: true

                    Canvas {
                        id: mainChartCanvas
                        anchors.fill: parent
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            const key = monitor.selectedResource;
                            const col1 = monitor.resourceColor(key);
                            if (key === "cpu") {
                                monitor.drawChart(ctx, width, height, SysStats.cpuHistory, col1, null, "transparent", true);
                            } else if (key === "memory") {
                                monitor.drawChart(ctx, width, height, SysStats.memHistory, col1, null, "transparent", true);
                            } else if (key === "disk") {
                                monitor.drawChart(ctx, width, height, SysStats.diskReadHistory, col1, SysStats.diskWriteHistory, Theme.primary, true);
                            } else if (key === "network") {
                                monitor.drawChart(ctx, width, height, SysStats.netRxHistory, col1, SysStats.netTxHistory, Theme.primary, true);
                            } else {
                                monitor.drawChart(ctx, width, height, SysStats.gpuHistory, col1, null, "transparent", true);
                            }
                        }
                    }
                }

                // B. Сетка логических процессоров (потоков) для ЦП (30 точек на ядро)
                GridLayout {
                    visible: monitor.selectedResource === "cpu" && monitor.cpuChartMode === "cores"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: (SysStats.coreHistories.length || SysStats.cores) > 12 ? 6
                           : ((SysStats.coreHistories.length || SysStats.cores) > 6 ? 4 : 2)
                    columnSpacing: Theme.dp(6)
                    rowSpacing: Theme.dp(6)

                    Repeater {
                        model: SysStats.coreHistories.length > 0 ? SysStats.coreHistories.length : SysStats.cores

                        delegate: Rectangle {
                            id: coreChartTile

                            required property int index

                            readonly property real curLoad: (SysStats.coreLoads && coreChartTile.index < SysStats.coreLoads.length)
                                ? SysStats.coreLoads[coreChartTile.index] : 0
                            readonly property int curMhz: (SysStats.coreMhz && coreChartTile.index < SysStats.coreMhz.length)
                                ? SysStats.coreMhz[coreChartTile.index] : SysStats.cpuCurMhz
                            readonly property var hist: (SysStats.coreHistories && coreChartTile.index < SysStats.coreHistories.length)
                                ? SysStats.coreHistories[coreChartTile.index] : []
                            readonly property color tileColor: coreChartTile.curLoad > 0.85 ? Theme.error
                                : (coreChartTile.curLoad > 0.65 ? Theme.warning : Theme.primary)

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.rad(8)
                            color: Theme.alpha(Theme.mLowest, 0.55)
                            border.width: 1
                            border.color: Theme.alpha(coreChartTile.tileColor, 0.35)
                            clip: true

                            Canvas {
                                anchors.fill: parent
                                property int tickRef: monitor.paintTick
                                onTickRefChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d");
                                    monitor.drawChart(ctx, width, height, coreChartTile.hist, coreChartTile.tileColor, null, "transparent", true);
                                }
                            }

                            RowLayout {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Theme.dp(5)
                                spacing: Theme.dp(4)

                                LText {
                                    role: "labelSmall"
                                    tabular: true
                                    color: Theme.subtext
                                    text: "ЦП " + coreChartTile.index
                                }
                                Item { Layout.fillWidth: true }
                                LText {
                                    role: "labelSmall"
                                    tabular: true
                                    color: Theme.subtextDim
                                    visible: coreChartTile.curMhz > 0
                                    text: coreChartTile.curMhz + " МГц"
                                }
                                LText {
                                    role: "labelSmall"
                                    tabular: true
                                    weight: 680
                                    color: coreChartTile.tileColor
                                    text: Math.round(coreChartTile.curLoad * 100) + "%"
                                }
                            }
                        }
                    }
                }

                // Подписи под графиком: 60 секунд слева, 0 справа
                RowLayout {
                    Layout.fillWidth: true
                    LText {
                        role: "labelSmall"
                        color: Theme.subtextDim
                        text: monitor.selectedResource === "cpu" && monitor.cpuChartMode === "cores"
                            ? "30 секунд истории по каждому ядру" : "60 секунд"
                    }
                    Item { Layout.fillWidth: true }
                    LText {
                        role: "labelSmall"
                        tabular: true
                        color: Theme.subtextDim
                        text: "0"
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════
        // 3. ДЕТАЛЬНАЯ ТЕЛЕМЕТРИЯ ВЫБРАННОГО РЕСУРСА (Windows 11 style)
        // ════════════════════════════════════════════════════════════════

        // ── 3A. ТЕЛЕМЕТРИЯ ЦП ─────────────────────────────────────────
        Rectangle {
            visible: monitor.selectedResource === "cpu"
            Layout.fillWidth: true
            implicitHeight: cpuTelemetryCol.implicitHeight + Theme.dp(24)
            radius: Theme.shapeLgInc
            color: Theme.mHigh

            ColumnLayout {
                id: cpuTelemetryCol
                anchors.fill: parent
                anchors.margins: Theme.dp(12)
                spacing: Theme.dp(10)

                // Верхний ряд крупных показателей (как в Windows 11)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(18)

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Использование" }
                        LText {
                            role: "headlineSmall"
                            tabular: true
                            weight: 700
                            color: SysStats.cpuPercent > 80 ? Theme.error : Theme.primary
                            text: SysStats.cpuPercent + "%"
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Скорость" }
                        LText {
                            role: "headlineSmall"
                            tabular: true
                            weight: 700
                            color: Theme.text
                            text: SysStats.cpuGhz + " ГГц"
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Процессы" }
                        LText {
                            role: "titleLarge"
                            tabular: true
                            weight: 640
                            color: Theme.text
                            text: String(SysStats.procCount || ProcList.totalCount)
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Потоки" }
                        LText {
                            role: "titleLarge"
                            tabular: true
                            weight: 640
                            color: Theme.text
                            text: String(SysStats.cpuThreadsTotal)
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Время работы (Uptime)" }
                        LText {
                            role: "titleLarge"
                            tabular: true
                            weight: 640
                            color: Theme.text
                            text: SysStats.formatUptime(SysStats.uptime)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Divider { Layout.fillWidth: true }

                // Нижняя сетка характеристик процессора
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: Theme.dp(18)
                    rowSpacing: Theme.dp(6)

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Базовая / Макс. скорость:" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: monitor.fmtGhz(SysStats.cpuBaseMhz) + " / " + monitor.fmtGhz(SysStats.cpuMaxMhz)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Ядра / Потоки:" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: (SysStats.physicalCores || SysStats.cores) + " / " + SysStats.cores
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Температура:" }
                        LText {
                            role: "bodyMedium"; tabular: true
                            color: monitor.tempTone(SysStats.tempC, 75, 85)
                            text: SysStats.tempC >= 0 ? Math.round(SysStats.tempC) + " °C" : "—"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Нагрузка (Load Avg):" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: monitor.fmtLoad(SysStats.load1) + " · " + monitor.fmtLoad(SysStats.load5) + " · " + monitor.fmtLoad(SysStats.load15)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Кэш L3:" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: SysStats.cpuCacheL3 !== "" ? SysStats.cpuCacheL3 : "—"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Виртуализация:" }
                        LText {
                            role: "bodyMedium"; color: Theme.text
                            text: SysStats.cpuVirt || "Включено"
                        }
                    }
                }
            }
        }

        // ── 3B. ТЕЛЕМЕТРИЯ ПАМЯТИ (Полоса структуры памяти + таблица) ──
        Rectangle {
            visible: monitor.selectedResource === "memory"
            Layout.fillWidth: true
            implicitHeight: memTelemetryCol.implicitHeight + Theme.dp(24)
            radius: Theme.shapeLgInc
            color: Theme.mHigh

            ColumnLayout {
                id: memTelemetryCol
                anchors.fill: parent
                anchors.margins: Theme.dp(12)
                spacing: Theme.dp(10)

                // Визуальная полоса состава памяти (Memory composition bar)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(5)

                    RowLayout {
                        Layout.fillWidth: true
                        LText { role: "labelMedium"; color: Theme.text; text: "Состав памяти" }
                        Item { Layout.fillWidth: true }
                        LText {
                            role: "labelSmall"; tabular: true; color: Theme.subtext
                            text: "Используется " + SysStats.formatBytes(SysStats.memUsed) + " из " + SysStats.formatBytes(SysStats.memTotal)
                        }
                    }

                    Rectangle {
                        id: compBar
                        Layout.fillWidth: true
                        implicitHeight: Theme.dp(18)
                        radius: Theme.rad(6)
                        color: Theme.bgTrack
                        clip: true

                        readonly property real totalB: Math.max(1, SysStats.memTotal)
                        readonly property real usedFrac: Math.max(0, Math.min(1, SysStats.memUsed / totalB))
                        readonly property real cacheBufFrac: Math.max(0, Math.min(1 - usedFrac, (SysStats.memCached + SysStats.memBuffers) / totalB))

                        // Сегмент 1: Используется приложениями
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.round(compBar.width * compBar.usedFrac)
                            color: Theme.tertiary
                        }

                        // Сегмент 2: Кэш + Буферы
                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            x: Math.round(compBar.width * compBar.usedFrac)
                            width: Math.round(compBar.width * compBar.cacheBufFrac)
                            color: Theme.alpha(Theme.primary, 0.55)
                        }
                    }

                    // Легенда полосы состава
                    RowLayout {
                        spacing: Theme.dp(14)

                        RowLayout {
                            spacing: Theme.dp(5)
                            Rectangle { width: Theme.dp(8); height: Theme.dp(8); radius: Theme.dp(2); color: Theme.tertiary }
                            LText { role: "labelSmall"; color: Theme.subtext; text: "В использовании (" + SysStats.formatBytes(SysStats.memUsed) + ")" }
                        }
                        RowLayout {
                            spacing: Theme.dp(5)
                            Rectangle { width: Theme.dp(8); height: Theme.dp(8); radius: Theme.dp(2); color: Theme.alpha(Theme.primary, 0.55) }
                            LText { role: "labelSmall"; color: Theme.subtext; text: "Кэш и буферы (" + SysStats.formatBytes(SysStats.memCached + SysStats.memBuffers) + ")" }
                        }
                        RowLayout {
                            spacing: Theme.dp(5)
                            Rectangle { width: Theme.dp(8); height: Theme.dp(8); radius: Theme.dp(2); color: Theme.bgTrack; border.width: 1; border.color: Theme.outline }
                            LText { role: "labelSmall"; color: Theme.subtext; text: "Доступно (" + SysStats.formatBytes(SysStats.memAvailable) + ")" }
                        }
                    }
                }

                Divider { Layout.fillWidth: true }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: Theme.dp(18)
                    rowSpacing: Theme.dp(6)

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Используется:" }
                        LText { role: "bodyMedium"; tabular: true; weight: 650; color: Theme.tertiary; text: SysStats.formatBytes(SysStats.memUsed) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Доступно:" }
                        LText { role: "bodyMedium"; tabular: true; color: Theme.text; text: SysStats.formatBytes(SysStats.memAvailable) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Кэшировано:" }
                        LText { role: "bodyMedium"; tabular: true; color: Theme.text; text: SysStats.formatBytes(SysStats.memCached) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Буферы:" }
                        LText { role: "bodyMedium"; tabular: true; color: Theme.text; text: SysStats.formatBytes(SysStats.memBuffers) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Dirty / Shared:" }
                        LText { role: "bodyMedium"; tabular: true; color: Theme.text; text: SysStats.formatBytes(SysStats.memDirty) + " / " + SysStats.formatBytes(SysStats.memShared) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Подкачка (Swap):" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: SysStats.swapTotal > 0
                                ? SysStats.formatBytes(SysStats.swapUsed) + " / " + SysStats.formatBytes(SysStats.swapTotal) + " (" + Math.round(SysStats.swapFrac * 100) + "%)"
                                : "Отключена"
                        }
                    }
                }
            }
        }

        // ── 3C. ТЕЛЕМЕТРИЯ ДИСКА (Скорость I/O + Точки монтирования) ──
        Rectangle {
            visible: monitor.selectedResource === "disk"
            Layout.fillWidth: true
            implicitHeight: diskTelemetryCol.implicitHeight + Theme.dp(24)
            radius: Theme.shapeLgInc
            color: Theme.mHigh

            ColumnLayout {
                id: diskTelemetryCol
                anchors.fill: parent
                anchors.margins: Theme.dp(12)
                spacing: Theme.dp(10)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(18)

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Скорость чтения" }
                        LText {
                            role: "titleLarge"; tabular: true; weight: 700; color: Theme.success
                            text: SysStats.formatRate(SysStats.diskReadRate)
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Скорость записи" }
                        LText {
                            role: "titleLarge"; tabular: true; weight: 700; color: Theme.primary
                            text: SysStats.formatRate(SysStats.diskWriteRate)
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Активное время" }
                        LText {
                            role: "titleLarge"; tabular: true; weight: 650; color: Theme.text
                            text: Math.round(SysStats.diskBusy * 100) + "%"
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Всего прочитано / записано" }
                        LText {
                            role: "titleSmall"; tabular: true; color: Theme.text
                            text: SysStats.formatBytes(SysStats.diskTotalRead) + " / " + SysStats.formatBytes(SysStats.diskTotalWrite)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Divider { Layout.fillWidth: true }

                // Карточки разделов (mount, device, fstype, used/total GB bar)
                GridLayout {
                    Layout.fillWidth: true
                    columns: SysStats.disks.length > 1 ? 2 : 1
                    columnSpacing: Theme.dp(10)
                    rowSpacing: Theme.dp(8)

                    Repeater {
                        model: SysStats.disks

                        delegate: Rectangle {
                            id: mntCard

                            required property var modelData
                            readonly property real frac: mntCard.modelData.total > 0
                                ? mntCard.modelData.used / mntCard.modelData.total : 0

                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(62)
                            radius: Theme.rad(10)
                            color: Theme.mLow
                            border.width: 1
                            border.color: Theme.alpha(Theme.outline, 0.14)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.dp(8)
                                spacing: Theme.dp(4)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.dp(6)

                                    Icon { name: "folder"; size: Theme.dp(15); color: Theme.success }
                                    LText {
                                        role: "labelLarge"; weight: 650; color: Theme.text
                                        text: mntCard.modelData.mount
                                    }
                                    LText {
                                        visible: Boolean(mntCard.modelData.device)
                                        role: "labelSmall"; color: Theme.subtextDim
                                        text: mntCard.modelData.device + (mntCard.modelData.fstype ? " · " + mntCard.modelData.fstype : "")
                                        elide: Text.ElideRight
                                    }
                                    Item { Layout.fillWidth: true }
                                    LText {
                                        role: "labelSmall"; tabular: true; color: Theme.text
                                        text: SysStats.formatBytes(mntCard.modelData.used) + " / " + SysStats.formatBytes(mntCard.modelData.total)
                                              + " (" + Math.round(mntCard.frac * 100) + "%)"
                                    }
                                }

                                LinearProgress {
                                    Layout.fillWidth: true
                                    value: mntCard.frac
                                    thickness: Theme.dp(6)
                                    wavy: false
                                    color: mntCard.frac > 0.9 ? Theme.error : (mntCard.frac > 0.78 ? Theme.warning : Theme.success)
                                    trackColor: Theme.alpha(Theme.text, 0.1)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 3D. ТЕЛЕМЕТРИЯ СЕТИ ───────────────────────────────────────
        Rectangle {
            visible: monitor.selectedResource === "network"
            Layout.fillWidth: true
            implicitHeight: netTelemetryCol.implicitHeight + Theme.dp(24)
            radius: Theme.shapeLgInc
            color: Theme.mHigh

            ColumnLayout {
                id: netTelemetryCol
                anchors.fill: parent
                anchors.margins: Theme.dp(12)
                spacing: Theme.dp(10)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(24)

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Скорость получения (RX)" }
                        LText {
                            role: "headlineSmall"; tabular: true; weight: 700; color: Theme.warning
                            text: SysStats.formatRate(SysStats.netRx)
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.dp(1)
                        LText { role: "labelSmall"; color: Theme.subtext; text: "Скорость отправки (TX)" }
                        LText {
                            role: "headlineSmall"; tabular: true; weight: 700; color: Theme.primary
                            text: SysStats.formatRate(SysStats.netTx)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Divider { Layout.fillWidth: true }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: Theme.dp(18)
                    rowSpacing: Theme.dp(6)

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Всего получено:" }
                        LText { role: "bodyMedium"; tabular: true; color: Theme.text; text: SysStats.formatBytes(SysStats.netTotalRx) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Всего отправлено:" }
                        LText { role: "bodyMedium"; tabular: true; color: Theme.text; text: SysStats.formatBytes(SysStats.netTotalTx) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Интерфейс:" }
                        LText { role: "bodyMedium"; color: Theme.text; text: SysStats.netIface || "—" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "IPv4 адрес:" }
                        LText { role: "bodyMedium"; tabular: true; color: Theme.text; text: SysStats.netIp || "—" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Имя узла:" }
                        LText { role: "bodyMedium"; color: Theme.text; text: SysStats.host || "—" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Ядро:" }
                        LText { role: "bodyMedium"; color: Theme.text; elide: Text.ElideRight; text: SysStats.kernel || "—" }
                    }
                }
            }
        }

        // ── 3E. ТЕЛЕМЕТРИЯ ГП + ДАТЧИКИ HWMON ─────────────────────────
        Rectangle {
            visible: monitor.selectedResource === "gpu"
            Layout.fillWidth: true
            implicitHeight: gpuTelemetryCol.implicitHeight + Theme.dp(24)
            radius: Theme.shapeLgInc
            color: Theme.mHigh

            ColumnLayout {
                id: gpuTelemetryCol
                anchors.fill: parent
                anchors.margins: Theme.dp(12)
                spacing: Theme.dp(10)

                // Полоса видеопамяти VRAM
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(4)

                    RowLayout {
                        Layout.fillWidth: true
                        LText { role: "labelMedium"; color: Theme.text; text: "Видеопамять (VRAM)" }
                        Item { Layout.fillWidth: true }
                        LText {
                            role: "labelSmall"; tabular: true; color: Theme.subtext
                            text: SysStats.vramTotal > 0
                                ? SysStats.formatBytes(SysStats.vramUsed) + " / " + SysStats.formatBytes(SysStats.vramTotal) + " (" + Math.round(SysStats.vramFrac * 100) + "%)"
                                : "Общая системная память"
                        }
                    }

                    LinearProgress {
                        Layout.fillWidth: true
                        value: SysStats.vramTotal > 0 ? SysStats.vramFrac : SysStats.memFrac
                        thickness: Theme.dp(8)
                        wavy: false
                        color: Theme.secondary
                        trackColor: Theme.alpha(Theme.text, 0.1)
                    }
                }

                Divider { Layout.fillWidth: true }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: Theme.dp(18)
                    rowSpacing: Theme.dp(6)

                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Загрузка ядра:" }
                        LText { role: "bodyMedium"; tabular: true; weight: 650; color: Theme.secondary; text: SysStats.gpuUsage + "%" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Температура:" }
                        LText {
                            role: "bodyMedium"; tabular: true
                            color: monitor.tempTone(SysStats.gpuTempC, 80, 90)
                            text: SysStats.gpuTempC >= 0 ? Math.round(SysStats.gpuTempC) + " °C" : "—"
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Энергопотребление:" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: SysStats.gpuPowerW > 0 ? Math.round(SysStats.gpuPowerW) + " Вт" : "—"
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Частота ядра:" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: SysStats.gpuSclkMhz > 0 ? SysStats.gpuSclkMhz + " МГц" : "—"
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Кулер:" }
                        LText {
                            role: "bodyMedium"; tabular: true; color: Theme.text
                            text: SysStats.gpuFanRpm > 0 ? SysStats.gpuFanRpm + " об/мин" : "—"
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LText { Layout.fillWidth: true; role: "bodySmall"; color: Theme.subtext; text: "Модель:" }
                        LText {
                            Layout.maximumWidth: Theme.dp(140)
                            role: "bodyMedium"; color: Theme.text; elide: Text.ElideRight
                            text: SysStats.gpuName || "—"
                        }
                    }
                }

                // Датчики hwmon (если есть)
                ColumnLayout {
                    visible: SysStats.temps.length > 0
                    Layout.fillWidth: true
                    spacing: Theme.dp(4)

                    Divider { Layout.fillWidth: true }

                    LText {
                        role: "labelSmall"
                        color: Theme.subtext
                        text: "Датчики температуры (hwmon)"
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: Theme.dp(14)
                        rowSpacing: Theme.dp(4)

                        Repeater {
                            model: SysStats.temps

                            delegate: RowLayout {
                                id: hwmonRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Theme.dp(6)

                                LText {
                                    Layout.fillWidth: true
                                    role: "labelSmall"
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    text: (hwmonRow.modelData.name && hwmonRow.modelData.label)
                                        ? (hwmonRow.modelData.name + " · " + hwmonRow.modelData.label)
                                        : (hwmonRow.modelData.label || hwmonRow.modelData.name || "Датчик")
                                }
                                LText {
                                    role: "labelSmall"
                                    tabular: true
                                    weight: 640
                                    color: monitor.tempTone(hwmonRow.modelData.c, 70, 85)
                                    text: Math.round(hwmonRow.modelData.c) + " °C"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
