import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Система» диспетчера задач: карточка-логотип Oberon слева и
// справочные данные о системе в Lucid-карточке справа (в духе fetch-скрипта).
// Данные — из SysStats, константы сборки заданы здесь же.
RowLayout {
    id: root

    // ── Константы шелла ────────────────────────────────────────────────
    readonly property string appName: "Oberon"
    readonly property string appVersion: "2.0"
    readonly property string compositorName: "Umbriel"
    readonly property string engineName: "Quickshell"
    readonly property string configPath: "~/oberon"
    readonly property string licenseName: "MIT"

    // максимальная температура среди датчиков hwmon
    readonly property real maxTempC: {
        let m = -1;
        const list = SysStats.temps || [];
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].c > m)
                m = list[i].c;
        return m;
    }

    // байты → «N.N ГБ»
    function fmtGb(bytes) {
        if (bytes === undefined || bytes === null || bytes < 0)
            return "—";
        return (bytes / 1073741824).toFixed(1) + " ГБ";
    }
    // секунды → «N ч M мин» (для долгих аптаймов — дни)
    function fmtUptime(sec) {
        const d = Math.floor(sec / 86400);
        const h = Math.floor((sec % 86400) / 3600);
        const m = Math.floor((sec % 3600) / 60);
        if (d > 0) return d + " д " + h + " ч";
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }
    // текущая и максимальная частота CPU компактно: «4.05/5.05 ГГц»
    function fmtClock() {
        const f = m => m > 0 ? (m / 1000).toFixed(2) : "—";
        if (SysStats.cpuCurMhz <= 0 && SysStats.cpuMaxMhz <= 0)
            return "—";
        return f(SysStats.cpuCurMhz) + "/" + f(SysStats.cpuMaxMhz) + " ГГц";
    }
    // диск → «544.0/952.9 ГБ»
    function fmtDisk(d) {
        if (!d || !isFinite(d.used) || !isFinite(d.total))
            return "—";
        return (d.used / 1073741824).toFixed(1) + "/" + (d.total / 1073741824).toFixed(1) + " ГБ";
    }
    // пустое значение → прочерк
    function orDash(v) { return (v === undefined || v === null || v === "") ? "—" : v }

    Layout.fillWidth: true
    spacing: Theme.dp(16)

    // ── Слева: карточка-логотип, имя и мини-чипы ──────────────────────
    Card {
        Layout.preferredWidth: Theme.dp(268)
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        pad: Theme.dp(20)

        Item { // логотип: фигура M3 circle, облако и искра
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(6)
            implicitWidth: Theme.dp(112)
            implicitHeight: Theme.dp(112)

            MaterialShape {
                anchors.fill: parent
                shape: "circle"
                color: Theme.accentContainer
            }

            Icon {
                anchors.centerIn: parent
                name: "cloud"
                size: Theme.dp(56)
                color: Theme.fgAccentContainer
            }

            Icon { // искра у облака
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenterOffset: Theme.dp(28)
                anchors.verticalCenterOffset: -Theme.dp(26)
                name: "star"
                size: Theme.dp(18)
                color: Theme.accent
            }
        }

        LText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(12)
            role: "headlineSmall"
            color: Theme.text
            text: root.appName
        }

        LText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(2)
            role: "bodySmall"
            color: Theme.subtext
            text: "M3 shell для " + root.compositorName
        }

        RowLayout { // мини-чипы: версия, лицензия, движок
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(16)
            spacing: Theme.dp(6)

            MiniChip { text: root.appVersion }
            MiniChip { text: root.licenseName }
            MiniChip { text: root.engineName }
        }
    }

    // ── Справа: Lucid-карточка с двумя колонками инфо-строк ───────────
    Card {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        title: "Система"
        pad: Theme.dp(18)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(18)

            ColumnLayout { // колонка A: система и процессор
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.dp(2)

                InfoRow { icon: "info"; label: "ОС"; value: root.orDash(SysStats.distro) }
                InfoRow { icon: "developer_board"; label: "Ядро"; value: root.orDash(SysStats.kernel) }
                InfoRow { icon: "monitor"; label: "Платформа"; value: root.orDash(SysStats.host) }
                InfoRow {
                    icon: "hourglass_top"; label: "Время работы"
                    value: SysStats.uptime > 0 ? root.fmtUptime(SysStats.uptime) : "—"
                }
                InfoRow { icon: "memory"; label: "Процессор"; value: root.orDash(SysStats.cpuModel) }
                InfoRow {
                    icon: "grid_view"; label: "Ядра/потоки"; tabular: true
                    value: SysStats.cores > 0 ? String(SysStats.cores) : "—"
                }
                InfoRow { icon: "speed"; label: "Частота CPU"; tabular: true; value: root.fmtClock() }
                InfoRow { icon: "storage"; label: "Память"; tabular: true; value: root.fmtGb(SysStats.memTotal) }
                InfoRow {
                    visible: root.maxTempC > 0
                    icon: "device_thermostat"; label: "Темп. CPU"; tabular: true
                    value: Math.round(root.maxTempC) + " °C"
                }
            }

            ColumnLayout { // колонка B: видеокарта, диски, софт
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.dp(2)

                InfoRow { icon: "graphic_eq"; label: "Видеокарта"; value: root.orDash(SysStats.gpuModel) }
                Repeater { // каждый mount — отдельная строка
                    model: SysStats.disks
                    delegate: ColumnLayout {
                        id: diskCol
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Theme.dp(2)

                        InfoRow {
                            icon: "storage"; label: diskCol.modelData.mount; tabular: true
                            value: root.fmtDisk(diskCol.modelData)
                        }
                    }
                }
                InfoRow { icon: "cloud"; label: "Шелл"; value: root.appName + " " + root.appVersion }
                InfoRow { icon: "dashboard"; label: "Композитор"; value: root.compositorName }
                InfoRow { icon: "settings"; label: "Движок"; value: root.engineName }
                InfoRow { icon: "folder"; label: "Конфиг"; value: root.configPath }
                InfoRow { icon: "flag"; label: "Лицензия"; value: root.licenseName }
            }
        }
    }

    // компактная инфо-строка: иконка на bgTrack, подпись и значение
    component InfoRow: Rectangle {
        id: infoRow

        property string icon: ""
        property string label: ""
        property string value: ""
        property bool tabular: false

        implicitHeight: Theme.dp(38)
        Layout.fillWidth: true
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: Theme.dp(10)

            Rectangle { // контейнер иконки
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.dp(30)
                implicitHeight: Theme.dp(30)
                radius: Theme.rad(10)
                color: Theme.bgTrack

                Icon {
                    anchors.centerIn: parent
                    name: infoRow.icon
                    size: Theme.dp(17)
                    color: Theme.subtext
                }
            }

            LText { // подпись
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
                role: "bodySmall"
                color: Theme.subtext
                text: infoRow.label
            }

            LText { // значение; длинные имена CPU/GPU обрезаются
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Theme.dp(170)
                elide: Text.ElideRight
                role: "bodyMedium"
                tabular: infoRow.tabular
                color: Theme.text
                text: infoRow.value
            }
        }
    }

    // мини-чип метаданных: labelSmall на bgTrack
    component MiniChip: Rectangle {
        id: chip

        property string text: ""

        implicitWidth: chipText.implicitWidth + Theme.dp(18)
        implicitHeight: Theme.dp(24)
        radius: Theme.radiusPill
        color: Theme.bgTrack

        LText {
            id: chipText
            anchors.centerIn: parent
            role: "labelSmall"
            color: Theme.subtext
            text: chip.text
        }
    }
}
