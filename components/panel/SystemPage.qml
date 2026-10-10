import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Система»: кольца CPU/RAM/GPU/диск и справка в две колонки.
// Всё должно влезать в панель без прокрутки Flickable.
ColumnLayout {
    id: page
    property var win: null
    Layout.fillWidth: true
    spacing: Theme.dp(10)
    visible: win !== null && win.mode === "panel" && win.page === "" && win.shell && win.shell.panelTab === "system"

    // байты → «N.N ГБ» (нулевое значение — это «0.0 ГБ», нет данных — «—»)
    function fmtGb(bytes) {
        if (bytes === undefined || bytes === null || bytes < 0) return "—";
        return (bytes / 1073741824).toFixed(1) + " ГБ";
    }
    // секунды → «N ч M мин»
    function fmtUptime(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }
    // МГц → «N.NN ГГц»
    function fmtGhz(mhz) { return (mhz / 1000).toFixed(2) + " ГГц" }
    // цвет кольца по порогам нагрузки (CPU/GPU)
    function cpuColor(v) { return v > 0.8 ? Theme.error : (v > 0.6 ? Theme.warning : Theme.accent) }

    // быстрые факты одной строкой; swap показывается только при наличии
    function quickFacts() {
        let s = "Нагрузка " + SysStats.load1.toFixed(2) + " / " + SysStats.load5.toFixed(2)
              + " · Процессы " + SysStats.procCount;
        if (page.hasSwap)
            s += " · Swap " + page.fmtGb(SysStats.swapUsed) + " / " + page.fmtGb(SysStats.swapTotal);
        return s;
    }

    // доступность опциональных метрик: скрывает и строку, и её разделитель
    readonly property bool hasSwap: SysStats.swapTotal > 0
    readonly property bool hasCpuTemp: SysStats.tempC > 0
    readonly property bool hasVram: SysStats.vramTotal > 0
    readonly property bool hasGpuTemp: SysStats.gpuTempC > 0
    readonly property bool hasGpuPower: SysStats.gpuPowerW >= 0
    readonly property bool hasGpuClk: SysStats.gpuSclkMhz > 0
    readonly property bool hasGpuFan: SysStats.gpuFanRpm > 0

    // компактная инфо-строка: иконка 28×28 на bgTrack, подпись, значение (высота 35)
    component InfoRow: Rectangle {
        id: infoRow
        property string icon: ""
        property string label: ""
        property string value: ""
        implicitHeight: Theme.dp(35)
        Layout.fillWidth: true
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: Theme.dp(6)

            Rectangle { // контейнер иконки
                implicitWidth: Theme.dp(28); implicitHeight: Theme.dp(28)
                radius: Theme.radiusSm
                color: Theme.bgTrack

                Icon {
                    anchors.centerIn: parent
                    name: infoRow.icon
                    size: Theme.dp(16)
                    color: Theme.subtext
                }
            }
            Text { // подпись
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: infoRow.label
                color: Theme.subtext
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }
            Text { // значение
                elide: Text.ElideRight
                text: infoRow.value
                color: Theme.text
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium")
            }
        }
    }

    // разделитель внутри колонки, вровень с текстом (после контейнера иконки)
    component RowSep: Divider {
        Layout.fillWidth: true
        leftInset: Theme.dp(34)
    }

    // верх: кольца живых метрик (CPU/RAM/GPU/Диск) и строка быстрых фактов
    Card {
        Layout.fillWidth: true
        title: SysStats.host

        RowLayout { // кольца 68px, ряд отцентрирован
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.dp(8)

            Item { Layout.fillWidth: true }

            Ring {
                Layout.preferredWidth: Theme.dp(68)
                Layout.preferredHeight: Theme.dp(68)
                thickness: Theme.dp(6)
                value: SysStats.cpu
                label: Math.round(SysStats.cpu * 100) + "%"
                caption: "CPU"
                color: page.cpuColor(SysStats.cpu)
            }
            Ring {
                Layout.preferredWidth: Theme.dp(68)
                Layout.preferredHeight: Theme.dp(68)
                thickness: Theme.dp(6)
                value: SysStats.memFrac
                label: Math.round(SysStats.memFrac * 100) + "%"
                caption: "RAM"
            }
            Ring {
                Layout.preferredWidth: Theme.dp(68)
                Layout.preferredHeight: Theme.dp(68)
                thickness: Theme.dp(6)
                value: SysStats.gpuBusy
                label: Math.round(SysStats.gpuBusy * 100) + "%"
                caption: "GPU"
                color: page.cpuColor(SysStats.gpuBusy)
            }
            Ring {
                Layout.preferredWidth: Theme.dp(68)
                Layout.preferredHeight: Theme.dp(68)
                thickness: Theme.dp(6)
                value: SysStats.diskFrac
                label: Math.round(SysStats.diskFrac * 100) + "%"
                caption: "Диск"
            }

            Item { Layout.fillWidth: true }
        }

        Text { // быстрые факты одной строкой
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(2)
            Layout.leftMargin: Theme.dp(8); Layout.rightMargin: Theme.dp(8)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: page.quickFacts()
            color: Theme.subtext
            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }
    }

    // справка о системе: две колонки компактных строк
    Card {
        Layout.fillWidth: true
        title: "О системе"
        pad: Theme.dp(12) // плотнее обычного: двум колонкам нужно место

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(12)

            ColumnLayout { // колонка A: система и ресурсы
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 0

                InfoRow { icon: "monitor"; label: "Хост"; value: SysStats.host }
                RowSep {}
                InfoRow { icon: "info"; label: "Ядро"; value: SysStats.kernel }
                RowSep {}
                InfoRow { icon: "hourglass_top"; label: "Время работы"; value: page.fmtUptime(SysStats.uptime) }
                RowSep {}
                InfoRow {
                    visible: page.hasCpuTemp
                    icon: "device_thermostat"; label: "Температура CPU"
                    value: Math.round(SysStats.tempC) + " °C"
                }
                RowSep { visible: page.hasCpuTemp }
                InfoRow {
                    icon: "memory"; label: "Память"
                    value: page.fmtGb(SysStats.memUsed) + " / " + page.fmtGb(SysStats.memTotal)
                }
                RowSep { visible: page.hasSwap }
                InfoRow {
                    visible: page.hasSwap
                    icon: "system_update_alt"; label: "Swap"
                    value: page.fmtGb(SysStats.swapUsed) + " / " + page.fmtGb(SysStats.swapTotal)
                }
            }

            ColumnLayout { // колонка B: CPU, GPU и железо
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 0

                InfoRow {
                    icon: "speed"; label: "CPU"
                    value: page.fmtGhz(SysStats.cpuCurMhz) + " / " + page.fmtGhz(SysStats.cpuMaxMhz)
                }
                RowSep {}
                InfoRow {
                    icon: "monitor_heart"; label: "Нагрузка"
                    value: SysStats.load1.toFixed(2) + " / " + SysStats.load5.toFixed(2)
                }
                RowSep {}
                InfoRow { icon: "apps"; label: "Процессы"; value: SysStats.procCount + "" }
                RowSep {}
                InfoRow {
                    icon: "storage"; label: "Диск"
                    value: page.fmtGb(SysStats.diskUsed) + " / " + page.fmtGb(SysStats.diskTotal)
                }
                RowSep {}
                InfoRow {
                    icon: "graphic_eq"; label: "GPU"
                    value: Math.round(SysStats.gpuBusy * 100) + "%"
                }
                RowSep { visible: page.hasVram }
                InfoRow {
                    visible: page.hasVram
                    icon: "developer_board"; label: "VRAM"
                    value: page.fmtGb(SysStats.vramUsed) + " / " + page.fmtGb(SysStats.vramTotal)
                }
                RowSep { visible: page.hasVram && page.hasGpuTemp }
                InfoRow {
                    visible: page.hasGpuTemp
                    icon: "device_thermostat"; label: "GPU-темп."
                    value: Math.round(SysStats.gpuTempC) + " °C"
                }
                RowSep { visible: page.hasGpuTemp && page.hasGpuPower }
                InfoRow {
                    visible: page.hasGpuPower
                    icon: "power"; label: "GPU-мощ."
                    value: Math.round(SysStats.gpuPowerW) + " Вт"
                }
                RowSep { visible: page.hasGpuPower && page.hasGpuClk }
                InfoRow {
                    visible: page.hasGpuClk
                    icon: "speed"; label: "Частота GPU"
                    value: SysStats.gpuSclkMhz + " МГц"
                }
                RowSep { visible: page.hasGpuClk && page.hasGpuFan }
                InfoRow {
                    visible: page.hasGpuFan
                    icon: "air"; label: "Верт. GPU"
                    value: SysStats.gpuFanRpm + " rpm"
                }
            }
        }
    }
}
