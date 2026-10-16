import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Монитор» диспетчера задач: сводка в две колонки Lucid-карточек —
// процессор/ядра/диски слева, видеокарта/память/сеть справа — и карточка
// температур во всю ширину внизу. Гейджи: волнистое кольцо для CPU/GPU и
// LinearProgress с бегущей волной для памяти/диска/VRAM; ряды — LText с
// tabular-цифрами. Тона accent → warning → error сохранены.
//
// Разметку держим «в линию» (без inline-компонентов): в этой сборке
// Quickshell они приводят к «Type … is not a type» при пересборке файла.
ColumnLayout {
    id: monitor

    property var shell: null

    // SysStats публикует temps/coreLoads готовыми массивами после опроса;
    // берём «липкие» копии после короткой паузы, когда поток строк завершён.
    property var coreView: []
    property var tempView: []

    Layout.fillWidth: true
    spacing: Theme.dp(14)

    Timer {
        id: viewSettle

        interval: 60

        onTriggered: {
            if (SysStats.coreLoads.length > 0)
                monitor.coreView = SysStats.coreLoads;
            if (SysStats.temps.length > 0)
                monitor.tempView = SysStats.temps;
        }
    }

    Connections {
        target: SysStats

        function onCoreLoadsChanged() {
            if (SysStats.coreLoads.length > 0)
                viewSettle.restart();
        }

        function onTempsChanged() {
            if (SysStats.temps.length > 0)
                viewSettle.restart();
        }
    }

    // ── форматирование ────────────────────────────────────────────────

    // байты → гигабайты с одним знаком: "5.2"
    function fmtGb(bytes) {
        if (!isFinite(bytes) || bytes < 0)
            return "—";
        return (bytes / 1073741824).toFixed(1);
    }

    // мегагерцы → гигагерцы: "4.2"
    function fmtGhz(mhz) {
        return ((isFinite(mhz) ? mhz : 0) / 1000).toFixed(1);
    }

    // секунды → "3д 4ч", "4ч 12м", "12м"
    function fmtUptime(sec) {
        const s = Math.max(0, Math.floor(sec || 0));
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return d + "д " + h + "ч";
        if (h > 0)
            return h + "ч " + m + "м";
        return m + "м";
    }

    // байт/с → "812 Б/с", "12.4 КБ/с", "3.1 МБ/с"
    function fmtSpeed(b) {
        if (!isFinite(b) || b < 0)
            return "—";
        if (b < 1024)
            return Math.round(b) + " Б/с";
        if (b < 1048576)
            return (b / 1024).toFixed(1) + " КБ/с";
        return (b / 1048576).toFixed(1) + " МБ/с";
    }

    // нагрузка (load average) с двумя знаками
    function fmtLoad(v) {
        return (isFinite(v) ? v : 0).toFixed(2);
    }

    // русское склонение: 1 поток, 2 потока, 16 потоков
    function plural(n, one, few, many) {
        const t = Math.abs(n) % 100;
        const o = t % 10;
        if (t >= 11 && t <= 14)
            return many;
        if (o === 1)
            return one;
        if (o >= 2 && o <= 4)
            return few;
        return many;
    }

    // цвет значения температуры по порогам предупреждения/ошибки
    function tempTone(c, warnAt, errAt) {
        if (c >= errAt)
            return Theme.error;
        if (c >= warnAt)
            return Theme.warning;
        return Theme.text;
    }

    // цвет бара заполнения: почти полный — ошибка, заметный — предупреждение
    function fillTone(frac) {
        if (frac > 0.92)
            return Theme.error;
        if (frac > 0.8)
            return Theme.warning;
        return Theme.accent;
    }

    // загрузка ядра из «липкой» копии (до первого полного тика — ноль)
    function coreAt(i) {
        return i >= 0 && i < monitor.coreView.length ? monitor.coreView[i] : 0;
    }

    // цвет ядра: 90 %+ — ошибка, 75 %+ — предупреждение
    function coreTone(frac) {
        if (frac >= 0.9)
            return Theme.error;
        if (frac >= 0.75)
            return Theme.warning;
        return Theme.accent;
    }

    // округлённый процент с зажимом в 0..100
    function pct(frac) {
        return Math.round(Math.max(0, Math.min(1, isFinite(frac) ? frac : 0)) * 100) + "%";
    }

    // трек гейджей: лёгкая подложка из чернил, как в Lucid
    readonly property color trackTone: Theme.a(Theme.text, 0.1)

    // колонки списка ядер: до восьми — одна, дальше две, чтобы не тянуть вниз
    readonly property int coreCols: SysStats.cores > 8 ? 2 : 1

    // есть ли вообще данные о видеокарте (иначе карточка целиком скрыта)
    readonly property bool hasGpu: SysStats.gpuTempC >= 0 || SysStats.gpuPowerW > 0
                                   || SysStats.gpuSclkMhz > 0 || SysStats.gpuFanRpm > 0
                                   || SysStats.vramTotal > 0 || SysStats.gpuBusy > 0

    // колонки карточки температур: держим 2–3, чтобы имена датчиков не резались
    readonly property int tempCols: monitor.tempView.length > 6 ? 3 : 2

    // датчики одной колонки при чтении «по строкам» слева направо
    function tempItems(col) {
        const out = [];
        const t = monitor.tempView;
        for (let i = col; i < t.length; i += monitor.tempCols)
            out.push(t[i]);
        return out;
    }

    // подпись датчика: имя чипа и метка, если обе есть
    function tempName(t) {
        if (!t)
            return "";
        if (t.name && t.label)
            return t.name + " · " + t.label;
        return t.label || t.name || "";
    }

    // ── две колонки карточек ──────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(14)

        // колонка 1: процессор, ядра, диски
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.dp(14)

            // ── Процессор: волнистое кольцо + строки характеристик ─────
            Card {
                Layout.fillWidth: true
                title: "Процессор"
                pad: Theme.dp(16)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(18)

                    CircularProgress { // волнистое кольцо загрузки, % в центре
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Theme.dp(84)
                        implicitHeight: Theme.dp(84)
                        value: SysStats.cpu
                        thickness: Theme.dp(7)
                        color: monitor.fillTone(SysStats.cpu)
                        trackColor: monitor.trackTone

                        content: LText {
                            anchors.centerIn: parent
                            role: "titleMedium"
                            weight: 680
                            tabular: true
                            color: Theme.text
                            text: Math.round(SysStats.cpu * 100) + "%"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(4)

                        // строка «подпись → значение»
                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(26)
                            spacing: Theme.dp(8)

                            LText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodySmall"
                                color: Theme.subtext
                                text: "Частота"
                                elide: Text.ElideRight
                            }
                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodyMedium"
                                tabular: true
                                color: Theme.text
                                text: SysStats.cpuMaxMhz > 0
                                      ? monitor.fmtGhz(SysStats.cpuCurMhz) + " / " + monitor.fmtGhz(SysStats.cpuMaxMhz) + " ГГц"
                                      : "—"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(26)
                            spacing: Theme.dp(8)

                            LText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodySmall"
                                color: Theme.subtext
                                text: "Нагрузка"
                                elide: Text.ElideRight
                            }
                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodyMedium"
                                tabular: true
                                color: Theme.text
                                text: monitor.fmtLoad(SysStats.load1) + " / " + monitor.fmtLoad(SysStats.load5)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(26)
                            spacing: Theme.dp(8)

                            LText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodySmall"
                                color: Theme.subtext
                                text: "Температура"
                                elide: Text.ElideRight
                            }
                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodyMedium"
                                tabular: true
                                color: monitor.tempTone(SysStats.tempC, 75, 85)
                                text: SysStats.tempC >= 0 && isFinite(SysStats.tempC)
                                      ? Math.round(SysStats.tempC) + " °C" : "—"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(26)
                            spacing: Theme.dp(8)

                            LText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodySmall"
                                color: Theme.subtext
                                text: "Ядра"
                                elide: Text.ElideRight
                            }
                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodyMedium"
                                tabular: true
                                color: Theme.text
                                text: SysStats.cores > 0
                                      ? SysStats.cores + " " + monitor.plural(SysStats.cores, "поток", "потока", "потоков")
                                      : "—"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(26)
                            spacing: Theme.dp(8)

                            LText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodySmall"
                                color: Theme.subtext
                                text: "Сеанс"
                                elide: Text.ElideRight
                            }
                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodyMedium"
                                tabular: true
                                color: Theme.text
                                text: monitor.fmtUptime(SysStats.uptime)
                            }
                        }
                    }
                }
            }

            // ── Ядра: компактный ряд «индекс + бар + %» ────────────────
            Card {
                Layout.fillWidth: true
                visible: SysStats.cores > 0
                title: "Ядра"
                pad: Theme.dp(16)

                GridLayout {
                    Layout.fillWidth: true
                    columns: monitor.coreCols
                    columnSpacing: Theme.dp(20)
                    rowSpacing: Theme.dp(6)

                    Repeater {
                        model: SysStats.cores

                        delegate: RowLayout {
                            id: coreCell

                            required property int index

                            readonly property real load: monitor.coreAt(coreCell.index)

                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(24)
                            spacing: Theme.dp(10)

                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(20)
                                horizontalAlignment: Text.AlignRight
                                role: "labelMedium"
                                tabular: true
                                color: Theme.subtext
                                text: String(coreCell.index)
                            }

                            LinearProgress { // мини-бар ядра
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                value: coreCell.load
                                thickness: Theme.dp(6)
                                wavy: false
                                color: monitor.coreTone(coreCell.load)
                                trackColor: monitor.trackTone
                            }

                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(40)
                                horizontalAlignment: Text.AlignRight
                                role: "labelMedium"
                                tabular: true
                                color: Theme.text
                                text: monitor.pct(coreCell.load)
                            }
                        }
                    }
                }
            }

            // ── Диски: по метрике на точку монтирования ────────────────
            Card {
                Layout.fillWidth: true
                visible: SysStats.disks.length > 0
                title: "Диски"
                pad: Theme.dp(16)

                Repeater {
                    model: SysStats.disks

                    delegate: ColumnLayout {
                        id: diskBlock

                        required property var modelData

                        readonly property real frac: diskBlock.modelData.total > 0 ? diskBlock.modelData.used / diskBlock.modelData.total : 0

                        Layout.fillWidth: true
                        Layout.topMargin: Theme.dp(8)
                        spacing: Theme.dp(7)

                        LText {
                            Layout.fillWidth: true
                            role: "labelLarge"
                            color: Theme.text
                            text: diskBlock.modelData.mount
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            LinearProgress { // бегущая волна заполнения
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                value: diskBlock.frac
                                thickness: Theme.dp(8)
                                wavy: true
                                color: monitor.fillTone(diskBlock.frac)
                                trackColor: monitor.trackTone
                            }

                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                role: "titleSmall"
                                tabular: true
                                color: Theme.text
                                text: monitor.pct(diskBlock.frac)
                            }
                        }

                        LText {
                            Layout.fillWidth: true
                            role: "bodySmall"
                            tabular: true
                            color: Theme.subtext
                            text: monitor.fmtGb(diskBlock.modelData.used) + " / " + monitor.fmtGb(diskBlock.modelData.total) + " ГБ"
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // колонка 2: видеокарта, память, сеть
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.dp(14)

            // ── Видеокарта: кольцо + характеристики + VRAM ─────────────
            Card {
                Layout.fillWidth: true
                visible: monitor.hasGpu
                title: "Видеокарта"
                pad: Theme.dp(16)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(14)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(18)

                        CircularProgress { // кольцо загрузки GPU, % в центре
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(84)
                            implicitHeight: Theme.dp(84)
                            value: SysStats.gpuBusy
                            thickness: Theme.dp(7)
                            color: monitor.fillTone(SysStats.gpuBusy)
                            trackColor: monitor.trackTone

                            content: LText {
                                anchors.centerIn: parent
                                role: "titleMedium"
                                weight: 680
                                tabular: true
                                color: Theme.text
                                text: Math.round(SysStats.gpuBusy * 100) + "%"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(4)

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuTempC >= 0 && isFinite(SysStats.gpuTempC)
                                implicitHeight: Theme.dp(26)
                                spacing: Theme.dp(8)

                                LText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodySmall"
                                    color: Theme.subtext
                                    text: "Температура"
                                    elide: Text.ElideRight
                                }
                                LText {
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodyMedium"
                                    tabular: true
                                    color: monitor.tempTone(SysStats.gpuTempC, 80, 90)
                                    text: Math.round(SysStats.gpuTempC) + " °C"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuPowerW > 0
                                implicitHeight: Theme.dp(26)
                                spacing: Theme.dp(8)

                                LText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodySmall"
                                    color: Theme.subtext
                                    text: "Мощность"
                                    elide: Text.ElideRight
                                }
                                LText {
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodyMedium"
                                    tabular: true
                                    color: Theme.text
                                    text: Math.round(SysStats.gpuPowerW) + " Вт"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuSclkMhz > 0
                                implicitHeight: Theme.dp(26)
                                spacing: Theme.dp(8)

                                LText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodySmall"
                                    color: Theme.subtext
                                    text: "Частота"
                                    elide: Text.ElideRight
                                }
                                LText {
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodyMedium"
                                    tabular: true
                                    color: Theme.text
                                    text: SysStats.gpuSclkMhz + " МГц"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuFanRpm > 0
                                implicitHeight: Theme.dp(26)
                                spacing: Theme.dp(8)

                                LText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodySmall"
                                    color: Theme.subtext
                                    text: "Вентилятор"
                                    elide: Text.ElideRight
                                }
                                LText {
                                    Layout.alignment: Qt.AlignVCenter
                                    role: "bodyMedium"
                                    tabular: true
                                    color: Theme.text
                                    text: SysStats.gpuFanRpm + " об/мин"
                                }
                            }
                        }
                    }

                    // VRAM: подпись + бар с процентом + деталь
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: SysStats.vramTotal > 0
                        spacing: Theme.dp(7)

                        LText {
                            Layout.fillWidth: true
                            role: "labelLarge"
                            color: Theme.text
                            text: "VRAM"
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            LinearProgress {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                value: SysStats.vramFrac
                                thickness: Theme.dp(8)
                                wavy: true
                                color: monitor.fillTone(SysStats.vramFrac)
                                trackColor: monitor.trackTone
                            }

                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                role: "titleSmall"
                                tabular: true
                                color: Theme.text
                                text: monitor.pct(SysStats.vramFrac)
                            }
                        }

                        LText {
                            Layout.fillWidth: true
                            role: "bodySmall"
                            tabular: true
                            color: Theme.subtext
                            text: monitor.fmtGb(SysStats.vramUsed) + " / " + monitor.fmtGb(SysStats.vramTotal) + " ГБ"
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ── Память: ОЗУ и swap ─────────────────────────────────────
            Card {
                Layout.fillWidth: true
                title: "Память"
                pad: Theme.dp(16)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(16)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(7)

                        LText {
                            Layout.fillWidth: true
                            role: "labelLarge"
                            color: Theme.text
                            text: "ОЗУ"
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            LinearProgress {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                value: SysStats.memFrac
                                thickness: Theme.dp(8)
                                wavy: true
                                color: monitor.fillTone(SysStats.memFrac)
                                trackColor: monitor.trackTone
                            }

                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                role: "titleSmall"
                                tabular: true
                                color: Theme.text
                                text: monitor.pct(SysStats.memFrac)
                            }
                        }

                        LText {
                            Layout.fillWidth: true
                            role: "bodySmall"
                            tabular: true
                            color: Theme.subtext
                            text: monitor.fmtGb(SysStats.memUsed) + " / " + monitor.fmtGb(SysStats.memTotal) + " ГБ"
                            elide: Text.ElideRight
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: SysStats.swapTotal > 0
                        spacing: Theme.dp(7)

                        LText {
                            Layout.fillWidth: true
                            role: "labelLarge"
                            color: Theme.text
                            text: "Swap"
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            LinearProgress {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                value: SysStats.swapFrac
                                thickness: Theme.dp(8)
                                wavy: true
                                color: Theme.secondary
                                trackColor: monitor.trackTone
                            }

                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                role: "titleSmall"
                                tabular: true
                                color: Theme.text
                                text: monitor.pct(SysStats.swapFrac)
                            }
                        }

                        LText {
                            Layout.fillWidth: true
                            role: "bodySmall"
                            tabular: true
                            color: Theme.subtext
                            text: monitor.fmtGb(SysStats.swapUsed) + " / " + monitor.fmtGb(SysStats.swapTotal) + " ГБ"
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ── Сеть: приём и отдача ───────────────────────────────────
            Card {
                Layout.fillWidth: true
                title: "Сеть"
                pad: Theme.dp(16)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(8)

                    RowLayout {
                        Layout.fillWidth: true
                        implicitHeight: Theme.dp(38)
                        spacing: Theme.dp(12)

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(38)
                            implicitHeight: Theme.dp(38)
                            radius: Theme.rad(12)
                            color: Theme.bgTrack

                            Icon {
                                anchors.centerIn: parent
                                name: "south"
                                size: Theme.dp(18)
                                color: Theme.accent
                            }
                        }

                        LText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            role: "bodyMedium"
                            color: Theme.subtext
                            text: "Скачивание"
                            elide: Text.ElideRight
                        }

                        LText {
                            Layout.alignment: Qt.AlignVCenter
                            role: "titleSmall"
                            tabular: true
                            color: Theme.text
                            text: monitor.fmtSpeed(SysStats.netRx)
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        implicitHeight: Theme.dp(38)
                        spacing: Theme.dp(12)

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(38)
                            implicitHeight: Theme.dp(38)
                            radius: Theme.rad(12)
                            color: Theme.bgTrack

                            Icon {
                                anchors.centerIn: parent
                                name: "north"
                                size: Theme.dp(18)
                                color: Theme.accent
                            }
                        }

                        LText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            role: "bodyMedium"
                            color: Theme.subtext
                            text: "Отправка"
                            elide: Text.ElideRight
                        }

                        LText {
                            Layout.alignment: Qt.AlignVCenter
                            role: "titleSmall"
                            tabular: true
                            color: Theme.text
                            text: monitor.fmtSpeed(SysStats.netTx)
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ── температуры: 2–3 равные колонки строк во всю ширину ───────────
    Card {
        Layout.fillWidth: true
        title: "Температуры"
        pad: Theme.dp(16)

        RowLayout { // пока датчики не найдены
            visible: monitor.tempView.length === 0
            Layout.fillWidth: true
            spacing: Theme.dp(12)
            implicitHeight: Theme.dp(34)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: "device_thermostat"
                size: Theme.dp(20)
                color: Theme.subtext
            }

            LText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                role: "bodyMedium"
                color: Theme.subtext
                text: "Датчики недоступны"
            }
        }

        RowLayout {
            visible: monitor.tempView.length > 0
            Layout.fillWidth: true
            spacing: Theme.dp(28)

            Repeater {
                model: monitor.tempCols

                delegate: ColumnLayout {
                    required property int index

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.dp(4)

                    Repeater {
                        model: monitor.tempItems(index)

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(30)
                            spacing: Theme.dp(12)

                            LText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                role: "bodySmall"
                                color: Theme.subtext
                                text: monitor.tempName(modelData)
                                elide: Text.ElideRight
                            }

                            LText {
                                Layout.alignment: Qt.AlignVCenter
                                role: "titleSmall"
                                tabular: true
                                color: monitor.tempTone(modelData ? modelData.c : -1, 60, 80)
                                text: modelData && isFinite(modelData.c)
                                      ? Math.round(modelData.c) + " °C" : "—"
                            }
                        }
                    }
                }
            }
        }
    }
}
