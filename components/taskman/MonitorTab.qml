import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Монитор» диспетчера задач: подробная статистика — процессор,
// видеокарта, память, диски и температуры. Внутри панели 920 (внутренняя
// ширина 888, высота контента ~620): RowLayout из двух равных колонок, ниже
// карточка датчиков во всю ширину. Внешней прокрутки нет — всё подогнано по
// высоте компактными паддингами (карточки pad 12, строки 26).
ColumnLayout {
    id: monitor

    property var shell: null

    Layout.fillWidth: true
    spacing: Theme.dp(10)

    // ── форматирование ────────────────────────────────────────────────

    // байты → гигабайты с одним знаком: "5.2"
    function fmtGb(bytes) {
        return (bytes / 1073741824).toFixed(1);
    }

    // мегагерцы → гигагерцы: "4.7"
    function fmtGhz(mhz) {
        return (mhz / 1000).toFixed(1);
    }

    // секунды → "3д 4ч", "4ч 12м", "12м"
    function fmtUptime(sec) {
        const s = Math.max(0, Math.floor(sec));
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return d + "д " + h + "ч";
        if (h > 0)
            return h + "ч " + m + "м";
        return m + "м";
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

    // цвет бара заполнения: >0.92 — ошибка, >0.8 — предупреждение, иначе акцент
    function fillTone(frac) {
        if (frac > 0.92)
            return Theme.error;
        if (frac > 0.8)
            return Theme.warning;
        return Theme.accent;
    }

    // есть ли вообще данные о видеокарте (иначе карточка целиком скрыта)
    readonly property bool hasGpu: SysStats.gpuTempC >= 0 || SysStats.gpuPowerW > 0
                                   || SysStats.gpuSclkMhz > 0 || SysStats.gpuFanRpm > 0
                                   || SysStats.vramTotal > 0 || SysStats.gpuBusy > 0

    // колонки сетки температур: чем больше датчиков, тем больше колонок
    readonly property int tempCols: SysStats.temps.length > 12 ? 4
                                  : SysStats.temps.length > 8 ? 3 : 2

    // датчики одной колонки при чтении «по строкам» слева направо
    function tempItems(col) {
        const out = [];
        const t = SysStats.temps;
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

    // бар заполнения 6px: трек bgTrack + заливка с плавным изменением
    component UsageBar: Item {
        id: ub

        property real frac: 0
        property color fillColor: Theme.accent

        Layout.fillWidth: true
        implicitHeight: Theme.dp(6)

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

    // ── две колонки: процессор/видеокарта и память/диски ──────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(10)

        // левая колонка
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
                        implicitWidth: Theme.dp(68)
                        implicitHeight: Theme.dp(68)
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
                            value: SysStats.load1.toFixed(2) + " / " + SysStats.load5.toFixed(2)
                        }
                        StatRow {
                            label: "Температура"
                            value: SysStats.tempC >= 0 ? Math.round(SysStats.tempC) + " °C" : "—"
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
                visible: monitor.hasGpu
                title: "Видеокарта"
                pad: Theme.dp(12)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.dp(14)

                    Ring {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Theme.dp(68)
                        implicitHeight: Theme.dp(68)
                        value: SysStats.gpuBusy
                        label: Math.round(SysStats.gpuBusy * 100) + "%"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.dp(2)

                        StatRow {
                            visible: SysStats.gpuTempC >= 0
                            label: "Температура"
                            value: Math.round(SysStats.gpuTempC) + " °C"
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
                            value: SysStats.gpuFanRpm + " rpm"
                        }

                        UsageBlock {
                            visible: SysStats.vramTotal > 0
                            label: "VRAM"
                            caption: monitor.fmtGb(SysStats.vramUsed) + " / " + monitor.fmtGb(SysStats.vramTotal) + " ГБ"
                            frac: SysStats.vramFrac
                        }
                    }
                }
            }
        }

        // правая колонка
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

        RowLayout {
            visible: SysStats.temps.length === 0
            Layout.fillWidth: true
            spacing: Theme.dp(8)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: "device_thermostat"
                size: Theme.dp(18)
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
            visible: SysStats.temps.length > 0
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
                            implicitHeight: Theme.dp(26)
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
                                text: Math.round(modelData.c) + " °C"
                                color: monitor.tempTone(modelData.c, 60, 80)
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
