import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Монитор» диспетчера задач: материальная сводка в две колонки
// карточек — процессор/ядра/диски слева, видеокарта/память/сеть справа —
// и карточка температур во всю ширину внизу. Внутри карточек — просторные
// ряды и толстые pill-бары, никаких разделителей: группируем отступами.
// Внутренняя ширина панели 888, высота укладывается в ~640 без внешней
// прокрутки: паддинги 16, строки 28–38, спейсинг 12–16.
//
// Разметку держим «в линию» (без inline-компонентов): в этой сборке
// Quickshell они приводят к «Type … is not a type» при пересборке файла.
ColumnLayout {
    id: monitor

    property var shell: null

    // SysStats обнуляет temps/coreLoads в начале каждого тика и наполняет их
    // заново, поэтому показываем «липкие» копии: копируем массив, когда поток
    // строк стих (60 мс). Иначе бары ядер и датчики мигали бы каждые 2 секунды.
    property var coreView: []
    property var tempView: []

    Layout.fillWidth: true
    spacing: Theme.dp(16)

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
        spacing: Theme.dp(16)

        // колонка 1: процессор, ядра, диски
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.dp(16)

            // ── Процессор: кольцо загрузки + строки характеристик ──────
            Card {
                Layout.fillWidth: true
                title: "Процессор"
                pad: Theme.dp(16)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(18)

                    Ring {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Theme.dp(76)
                        implicitHeight: Theme.dp(76)
                        value: SysStats.cpu
                        label: Math.round(SysStats.cpu * 100) + "%"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(4)

                        // строка «подпись → значение»
                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(28)
                            spacing: Theme.dp(8)

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: "Частота"
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: SysStats.cpuMaxMhz > 0
                                      ? monitor.fmtGhz(SysStats.cpuCurMhz) + " / " + monitor.fmtGhz(SysStats.cpuMaxMhz) + " ГГц"
                                      : "—"
                                color: Theme.text
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyMedium")
                                font.weight: Theme.typeWeight("bodyMedium")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(28)
                            spacing: Theme.dp(8)

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: "Нагрузка"
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: monitor.fmtLoad(SysStats.load1) + " / " + monitor.fmtLoad(SysStats.load5)
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyMedium")
                                font.weight: Theme.typeWeight("bodyMedium")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(28)
                            spacing: Theme.dp(8)

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: "Температура"
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: SysStats.tempC >= 0 && isFinite(SysStats.tempC)
                                      ? Math.round(SysStats.tempC) + " °C" : "—"
                                color: monitor.tempTone(SysStats.tempC, 75, 85)
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyMedium")
                                font.weight: Theme.typeWeight("bodyMedium")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(28)
                            spacing: Theme.dp(8)

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: "Ядра"
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: SysStats.cores > 0
                                      ? SysStats.cores + " " + monitor.plural(SysStats.cores, "поток", "потока", "потоков")
                                      : "—"
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyMedium")
                                font.weight: Theme.typeWeight("bodyMedium")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(28)
                            spacing: Theme.dp(8)

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: "Сеанс"
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: monitor.fmtUptime(SysStats.uptime)
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyMedium")
                                font.weight: Theme.typeWeight("bodyMedium")
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
                    rowSpacing: Theme.dp(4)

                    Repeater {
                        model: SysStats.cores

                        delegate: RowLayout {
                            id: coreCell

                            required property int index

                            readonly property real load: monitor.coreAt(coreCell.index)

                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(24)
                            spacing: Theme.dp(10)

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(20)
                                horizontalAlignment: Text.AlignRight
                                text: String(coreCell.index)
                                color: Theme.subtext
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("labelMedium")
                                font.weight: Theme.typeWeight("labelMedium")
                            }

                            // мини pill-бар ядра: трек + заливка по порогам
                            Item {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: Theme.dp(8)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.pill(height)
                                    color: Theme.bgTrack
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * Math.max(0, Math.min(1, coreCell.load))
                                    radius: Theme.pill(height)
                                    color: monitor.coreTone(coreCell.load)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveDefaultSpatial
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(40)
                                horizontalAlignment: Text.AlignRight
                                text: monitor.pct(coreCell.load)
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("labelMedium")
                                font.weight: Theme.typeWeight("labelMedium")
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

                        Layout.fillWidth: true
                        Layout.topMargin: Theme.dp(8)
                        spacing: Theme.dp(7)

                        Text {
                            Layout.fillWidth: true
                            text: diskBlock.modelData.mount
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("labelLarge")
                            font.weight: Theme.typeWeight("labelLarge")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: Theme.dp(12)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.pill(height)
                                    color: Theme.bgTrack
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * Math.max(0, Math.min(1, diskBlock.modelData.total > 0 ? diskBlock.modelData.used / diskBlock.modelData.total : 0))
                                    radius: Theme.pill(height)
                                    color: monitor.fillTone(diskBlock.modelData.total > 0 ? diskBlock.modelData.used / diskBlock.modelData.total : 0)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveDefaultSpatial
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                text: monitor.pct(diskBlock.modelData.total > 0 ? diskBlock.modelData.used / diskBlock.modelData.total : 0)
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("titleSmall")
                                font.weight: Theme.typeWeight("titleSmall")
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: monitor.fmtGb(diskBlock.modelData.used) + " / " + monitor.fmtGb(diskBlock.modelData.total) + " ГБ"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }
                    }
                }
            }
        }

        // колонка 2: видеокарта, память, сеть
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.dp(16)

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

                        Ring {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(76)
                            implicitHeight: Theme.dp(76)
                            value: SysStats.gpuBusy
                            label: Math.round(SysStats.gpuBusy * 100) + "%"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(4)

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuTempC >= 0 && isFinite(SysStats.gpuTempC)
                                implicitHeight: Theme.dp(28)
                                spacing: Theme.dp(8)

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Температура"
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodySmall")
                                    font.weight: Theme.typeWeight("bodySmall")
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: Math.round(SysStats.gpuTempC) + " °C"
                                    color: monitor.tempTone(SysStats.gpuTempC, 80, 90)
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodyMedium")
                                    font.weight: Theme.typeWeight("bodyMedium")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuPowerW > 0
                                implicitHeight: Theme.dp(28)
                                spacing: Theme.dp(8)

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Мощность"
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodySmall")
                                    font.weight: Theme.typeWeight("bodySmall")
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: Math.round(SysStats.gpuPowerW) + " Вт"
                                    color: Theme.text
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodyMedium")
                                    font.weight: Theme.typeWeight("bodyMedium")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuSclkMhz > 0
                                implicitHeight: Theme.dp(28)
                                spacing: Theme.dp(8)

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Частота"
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodySmall")
                                    font.weight: Theme.typeWeight("bodySmall")
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: SysStats.gpuSclkMhz + " МГц"
                                    color: Theme.text
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodyMedium")
                                    font.weight: Theme.typeWeight("bodyMedium")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: SysStats.gpuFanRpm > 0
                                implicitHeight: Theme.dp(28)
                                spacing: Theme.dp(8)

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Вентилятор"
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodySmall")
                                    font.weight: Theme.typeWeight("bodySmall")
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: SysStats.gpuFanRpm + " об/мин"
                                    color: Theme.text
                                    font.family: Theme.textFont
                                    font.pixelSize: Theme.typeSize("bodyMedium")
                                    font.weight: Theme.typeWeight("bodyMedium")
                                }
                            }
                        }
                    }

                    // VRAM: подпись + бар с процентом + деталь
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: SysStats.vramTotal > 0
                        spacing: Theme.dp(7)

                        Text {
                            Layout.fillWidth: true
                            text: "VRAM"
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("labelLarge")
                            font.weight: Theme.typeWeight("labelLarge")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: Theme.dp(12)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.pill(height)
                                    color: Theme.bgTrack
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * Math.max(0, Math.min(1, SysStats.vramFrac))
                                    radius: Theme.pill(height)
                                    color: monitor.fillTone(SysStats.vramFrac)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveDefaultSpatial
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                text: monitor.pct(SysStats.vramFrac)
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("titleSmall")
                                font.weight: Theme.typeWeight("titleSmall")
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: monitor.fmtGb(SysStats.vramUsed) + " / " + monitor.fmtGb(SysStats.vramTotal) + " ГБ"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
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

                        Text {
                            Layout.fillWidth: true
                            text: "ОЗУ"
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("labelLarge")
                            font.weight: Theme.typeWeight("labelLarge")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: Theme.dp(12)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.pill(height)
                                    color: Theme.bgTrack
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * Math.max(0, Math.min(1, SysStats.memFrac))
                                    radius: Theme.pill(height)
                                    color: monitor.fillTone(SysStats.memFrac)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveDefaultSpatial
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                text: monitor.pct(SysStats.memFrac)
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("titleSmall")
                                font.weight: Theme.typeWeight("titleSmall")
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: monitor.fmtGb(SysStats.memUsed) + " / " + monitor.fmtGb(SysStats.memTotal) + " ГБ"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: SysStats.swapTotal > 0
                        spacing: Theme.dp(7)

                        Text {
                            Layout.fillWidth: true
                            text: "Swap"
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("labelLarge")
                            font.weight: Theme.typeWeight("labelLarge")
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(12)

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: Theme.dp(12)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.pill(height)
                                    color: Theme.bgTrack
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * Math.max(0, Math.min(1, SysStats.swapFrac))
                                    radius: Theme.pill(height)
                                    color: Theme.secondary

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveDefaultSpatial
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(44)
                                horizontalAlignment: Text.AlignRight
                                text: monitor.pct(SysStats.swapFrac)
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("titleSmall")
                                font.weight: Theme.typeWeight("titleSmall")
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: monitor.fmtGb(SysStats.swapUsed) + " / " + monitor.fmtGb(SysStats.swapTotal) + " ГБ"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
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
                            radius: Theme.radiusMd
                            color: Theme.bgTrack

                            Icon {
                                anchors.centerIn: parent
                                name: "south"
                                size: Theme.dp(18)
                                color: Theme.accent
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: "Скачивание"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyMedium")
                            font.weight: Theme.typeWeight("bodyMedium")
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: monitor.fmtSpeed(SysStats.netRx)
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("titleMedium")
                            font.weight: Theme.typeWeight("titleMedium")
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
                            radius: Theme.radiusMd
                            color: Theme.bgTrack

                            Icon {
                                anchors.centerIn: parent
                                name: "north"
                                size: Theme.dp(18)
                                color: Theme.accent
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: "Отправка"
                            color: Theme.subtext
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyMedium")
                            font.weight: Theme.typeWeight("bodyMedium")
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: monitor.fmtSpeed(SysStats.netTx)
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("titleMedium")
                            font.weight: Theme.typeWeight("titleMedium")
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

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: "Датчики недоступны"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium")
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

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: monitor.tempName(modelData)
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData && isFinite(modelData.c)
                                      ? Math.round(modelData.c) + " °C" : "—"
                                color: monitor.tempTone(modelData ? modelData.c : -1, 60, 80)
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("titleSmall")
                                font.weight: Theme.typeWeight("titleSmall")
                            }
                        }
                    }
                }
            }
        }
    }
}
