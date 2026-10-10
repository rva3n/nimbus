import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Монитор» диспетчера задач: плотная сводка в три колонки —
// процессор с сеткой ядер, видеокарта с сетью, память с дисками — и карточка
// температур во всю ширину. Внутренняя ширина панели 888, высота умещается
// в ~640 без внешней прокрутки: паддинги карточек 12, строки 24–26,
// spacing 2–10. Пустого места не держим — у каждой метрики свой ряд.
ColumnLayout {
    id: monitor

    property var shell: null

    // SysStats обнуляет temps/coreLoads в начале каждого тика и наполняет их
    // заново, поэтому показываем «липкие» копии: копируем массив, когда поток
    // строк стих (60 мс). Иначе бары ядер и датчики мигали бы каждые 2 секунды.
    property var coreView: []
    property var tempView: []

    Layout.fillWidth: true
    spacing: Theme.dp(10)

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

    // колонки сетки ядер: 12 и больше — 4×3, иначе три
    readonly property int coreCols: SysStats.cores >= 12 ? 4
                                    : SysStats.cores >= 6 ? 3 : 2

    // есть ли вообще данные о видеокарте (иначе карточка целиком скрыта)
    readonly property bool hasGpu: SysStats.gpuTempC >= 0 || SysStats.gpuPowerW > 0
                                   || SysStats.gpuSclkMhz > 0 || SysStats.gpuFanRpm > 0
                                   || SysStats.vramTotal > 0 || SysStats.gpuBusy > 0

    // колонки карточки температур: чем больше датчиков, тем больше колонок
    readonly property int tempCols: monitor.tempView.length > 12 ? 4
                                  : monitor.tempView.length > 8 ? 3 : 2

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

    // ── локальные компоненты ──────────────────────────────────────────

    // строка «подпись → значение»: bodySmall/subtext и bodyMedium/text
    component StatRow: RowLayout {
        id: sr

        property string label: ""
        property string value: ""
        property color valueColor: Theme.text

        Layout.fillWidth: true
        implicitHeight: Theme.dp(26)
        spacing: Theme.dp(8)

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: sr.label
            color: Theme.subtext
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: sr.value
            color: sr.valueColor
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }
    }

    // бар заполнения: трек bgTrack + заливка с плавным изменением
    component UsageBar: Item {
        id: ub

        property real frac: 0
        property color fillColor: Theme.accent
        property real thickness: Theme.dp(6)

        Layout.fillWidth: true
        implicitHeight: ub.thickness

        Rectangle {
            anchors.fill: parent
            radius: Theme.pill(height)
            color: Theme.bgTrack
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, ub.frac))
            radius: Theme.pill(height)
            color: ub.fillColor

            Behavior on width {
                NumberAnimation {
                    duration: Theme.ms(420)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }
            }
        }
    }

    // блок «подпись + X / Y ГБ», под ним бар — ОЗУ, swap, VRAM, диски
    component UsageBlock: ColumnLayout {
        id: blk

        property string label: ""
        property string caption: ""
        property real frac: 0
        property color fillColor: Theme.accent

        Layout.fillWidth: true
        spacing: Theme.dp(3)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(8)

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: blk.label
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium")
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: blk.caption
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }
        }

        UsageBar {
            frac: blk.frac
            fillColor: blk.fillColor
        }
    }

    // строка сети: стрелка, подпись и крупное значение скорости
    component NetRow: RowLayout {
        id: nr

        property string icon: ""
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        implicitHeight: Theme.dp(30)
        spacing: Theme.dp(8)

        Icon {
            Layout.alignment: Qt.AlignVCenter
            name: nr.icon
            size: Theme.dp(14)
            color: Theme.accent
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: nr.label
            color: Theme.subtext
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: nr.value
            color: Theme.text
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("titleSmall")
            font.weight: Theme.typeWeight("titleSmall")
        }
    }

    // ── три колонки метрик ────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(10)

        // колонка 1: процессор и ядра
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.dp(10)

            Card {
                Layout.fillWidth: true
                title: "Процессор"
                pad: Theme.dp(12)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(14)

                    Ring {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Theme.dp(64)
                        implicitHeight: Theme.dp(64)
                        value: SysStats.cpu
                        label: Math.round(SysStats.cpu * 100) + "%"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(2)

                        StatRow {
                            label: "Частота"
                            value: SysStats.cpuMaxMhz > 0
                                   ? monitor.fmtGhz(SysStats.cpuCurMhz) + " / " + monitor.fmtGhz(SysStats.cpuMaxMhz) + " ГГц"
                                   : "—"
                        }
                        StatRow {
                            label: "Нагрузка"
                            value: monitor.fmtLoad(SysStats.load1) + " / " + monitor.fmtLoad(SysStats.load5)
                        }
                        StatRow {
                            label: "Температура"
                            value: SysStats.tempC >= 0 && isFinite(SysStats.tempC)
                                   ? Math.round(SysStats.tempC) + " °C" : "—"
                            valueColor: monitor.tempTone(SysStats.tempC, 75, 85)
                        }
                        StatRow {
                            label: "Ядра"
                            value: SysStats.cores > 0
                                   ? SysStats.cores + " " + monitor.plural(SysStats.cores, "поток", "потока", "потоков")
                                   : "—"
                        }
                        StatRow {
                            label: "Сеанс"
                            value: monitor.fmtUptime(SysStats.uptime)
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                title: "Ядра"
                pad: Theme.dp(12)

                GridLayout {
                    Layout.fillWidth: true
                    columns: monitor.coreCols
                    columnSpacing: Theme.dp(8)
                    rowSpacing: Theme.dp(6)

                    Repeater {
                        model: SysStats.cores

                        delegate: RowLayout {
                            id: coreCell

                            required property int index

                            readonly property real load: monitor.coreAt(coreCell.index)

                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(16)
                            spacing: Theme.dp(4)

                            Text { // индекс ядра
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(12)
                                horizontalAlignment: Text.AlignRight
                                text: String(coreCell.index)
                                color: Theme.subtext
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("labelSmall")
                                font.weight: Theme.typeWeight("labelSmall")
                            }

                            UsageBar {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                thickness: Theme.dp(4)
                                frac: coreCell.load
                                fillColor: monitor.coreTone(coreCell.load)
                            }

                            Text { // процент загрузки, до трёх знаков
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Theme.dp(26)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(coreCell.load * 100) + "%"
                                color: Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("labelSmall")
                                font.weight: Theme.typeWeight("labelSmall")
                            }
                        }
                    }
                }
            }
        }

        // колонка 2: видеокарта и сеть
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.dp(10)

            Card {
                Layout.fillWidth: true
                visible: monitor.hasGpu
                title: "Видеокарта"
                pad: Theme.dp(12)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(8)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(14)

                        Ring {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(64)
                            implicitHeight: Theme.dp(64)
                            value: SysStats.gpuBusy
                            label: Math.round(SysStats.gpuBusy * 100) + "%"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.dp(2)

                            StatRow {
                                visible: SysStats.gpuTempC >= 0 && isFinite(SysStats.gpuTempC)
                                label: "Температура"
                                value: Math.round(SysStats.gpuTempC) + " °C"
                                valueColor: monitor.tempTone(SysStats.gpuTempC, 80, 90)
                            }
                            StatRow {
                                visible: SysStats.gpuPowerW > 0
                                label: "Мощность"
                                value: Math.round(SysStats.gpuPowerW) + " Вт"
                            }
                            StatRow {
                                visible: SysStats.gpuSclkMhz > 0
                                label: "Частота"
                                value: SysStats.gpuSclkMhz + " МГц"
                            }
                            StatRow {
                                visible: SysStats.gpuFanRpm > 0
                                label: "Вентилятор"
                                value: SysStats.gpuFanRpm + " об/мин"
                            }
                        }
                    }

                    UsageBlock {
                        visible: SysStats.vramTotal > 0
                        label: "VRAM"
                        caption: monitor.fmtGb(SysStats.vramUsed) + " / " + monitor.fmtGb(SysStats.vramTotal) + " ГБ"
                        frac: SysStats.vramFrac
                        fillColor: monitor.fillTone(SysStats.vramFrac)
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                title: "Сеть"
                pad: Theme.dp(12)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(2)

                    NetRow {
                        icon: "south"
                        label: "Скачивание"
                        value: monitor.fmtSpeed(SysStats.netRx)
                    }

                    Divider {
                        Layout.fillWidth: true
                    }

                    NetRow {
                        icon: "north"
                        label: "Отправка"
                        value: monitor.fmtSpeed(SysStats.netTx)
                    }
                }
            }
        }

        // колонка 3: память и диски
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.dp(10)

            Card {
                Layout.fillWidth: true
                title: "Память"
                pad: Theme.dp(12)

                UsageBlock {
                    label: "ОЗУ"
                    caption: monitor.fmtGb(SysStats.memUsed) + " / " + monitor.fmtGb(SysStats.memTotal) + " ГБ"
                    frac: SysStats.memFrac
                    fillColor: monitor.fillTone(SysStats.memFrac)
                }

                UsageBlock {
                    visible: SysStats.swapTotal > 0
                    label: "Swap"
                    caption: monitor.fmtGb(SysStats.swapUsed) + " / " + monitor.fmtGb(SysStats.swapTotal) + " ГБ"
                    frac: SysStats.swapFrac
                    fillColor: monitor.fillTone(SysStats.swapFrac)
                }
            }

            Card {
                Layout.fillWidth: true
                visible: SysStats.disks.length > 0
                title: "Диски"
                pad: Theme.dp(12)

                Repeater {
                    model: SysStats.disks

                    delegate: ColumnLayout {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: Theme.dp(4)

                        Divider {
                            visible: index > 0
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.dp(2)
                        }

                        UsageBlock {
                            label: modelData.mount
                            caption: monitor.fmtGb(modelData.used) + " / " + monitor.fmtGb(modelData.total) + " ГБ"
                            frac: modelData.total > 0 ? modelData.used / modelData.total : 0
                            fillColor: monitor.fillTone(modelData.total > 0 ? modelData.used / modelData.total : 0)
                        }
                    }
                }
            }
        }
    }

    // ── температуры: 2–4 равные колонки мини-строк во всю ширину ──────
    Card {
        Layout.fillWidth: true
        title: "Температуры"
        pad: Theme.dp(12)

        RowLayout { // пока датчики не найдены
            visible: monitor.tempView.length === 0
            Layout.fillWidth: true
            spacing: Theme.dp(8)
            implicitHeight: Theme.dp(24)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: "device_thermostat"
                size: Theme.dp(16)
                color: Theme.subtext
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: "Датчики недоступны"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }
        }

        RowLayout {
            visible: monitor.tempView.length > 0
            Layout.fillWidth: true
            spacing: Theme.dp(16)

            Repeater {
                model: monitor.tempCols

                delegate: ColumnLayout {
                    required property int index

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.dp(2)

                    Repeater {
                        model: monitor.tempItems(index)

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: Theme.dp(24)
                            spacing: Theme.dp(8)

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: monitor.tempName(modelData)
                                color: Theme.subtext
                                elide: Text.ElideRight
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("labelSmall")
                                font.weight: Theme.typeWeight("labelSmall")
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
