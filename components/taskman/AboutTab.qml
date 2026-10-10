import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Система» диспетчера задач: рисованный логотип Nimbus слева и
// справочная таблица о системе в две колонки справа (в духе fetch-скрипта).
// Данные — из SysStats, константы сборки заданы здесь же.
RowLayout {
    id: root

    // ── Константы шелла ────────────────────────────────────────────────
    readonly property string appName: "Nimbus"
    readonly property string appVersion: "2.0"
    readonly property string compositorName: "Umbriel"
    readonly property string engineName: "Quickshell"
    readonly property string configPath: "~/nimbus"
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
    spacing: Theme.dp(20)

    // ── Слева: логотип, имя и мини-чипы ────────────────────────────────
    ColumnLayout {
        Layout.preferredWidth: Theme.dp(260)
        Layout.alignment: Qt.AlignTop
        spacing: 0

        Item { // логотип: круг accentContainer, облако и искра
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Theme.dp(112)
            implicitHeight: Theme.dp(112)

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.accentContainer

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
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(12)
            text: root.appName
            color: Theme.text
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("headlineSmall")
            font.weight: Theme.typeWeight("headlineSmall")
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(2)
            text: "M3 shell для " + root.compositorName
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
        }

        RowLayout { // мини-чипы: версия, лицензия, движок
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(14)
            spacing: Theme.dp(6)

            MiniChip { text: root.appVersion }
            MiniChip { text: root.licenseName }
            MiniChip { text: root.engineName }
        }
    }

    // ── Справа: две колонки инфо-строк ─────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Theme.dp(14)

        ColumnLayout { // колонка A: система и процессор
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 0

            InfoRow { icon: "info"; label: "ОС"; value: root.orDash(SysStats.distro) }
            RowSep {}
            InfoRow { icon: "developer_board"; label: "Ядро"; value: root.orDash(SysStats.kernel) }
            RowSep {}
            InfoRow { icon: "monitor"; label: "Платформа"; value: root.orDash(SysStats.host) }
            RowSep {}
            InfoRow {
                icon: "hourglass_top"; label: "Время работы"
                value: SysStats.uptime > 0 ? root.fmtUptime(SysStats.uptime) : "—"
            }
            RowSep {}
            InfoRow { icon: "memory"; label: "Процессор"; value: root.orDash(SysStats.cpuModel) }
            RowSep {}
            InfoRow {
                icon: "grid_view"; label: "Ядра/потоки"
                value: SysStats.cores > 0 ? String(SysStats.cores) : "—"
            }
            RowSep {}
            InfoRow { icon: "speed"; label: "Частота CPU"; value: root.fmtClock() }
            RowSep {}
            InfoRow { icon: "storage"; label: "Память"; value: root.fmtGb(SysStats.memTotal) }
            RowSep { visible: root.maxTempC > 0 }
            InfoRow {
                visible: root.maxTempC > 0
                icon: "device_thermostat"; label: "Темп. CPU"
                value: Math.round(root.maxTempC) + " °C"
            }
        }

        ColumnLayout { // колонка B: видеокарта, диски, софт
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 0

            InfoRow { icon: "graphic_eq"; label: "Видеокарта"; value: root.orDash(SysStats.gpuModel) }
            RowSep {}
            Repeater { // каждый mount — отдельная строка
                model: SysStats.disks
                delegate: ColumnLayout {
                    id: diskCol
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 0

                    InfoRow {
                        icon: "storage"; label: diskCol.modelData.mount
                        value: root.fmtDisk(diskCol.modelData)
                    }
                    RowSep {}
                }
            }
            InfoRow { icon: "cloud"; label: "Шелл"; value: root.appName + " " + root.appVersion }
            RowSep {}
            InfoRow { icon: "dashboard"; label: "Композитор"; value: root.compositorName }
            RowSep {}
            InfoRow { icon: "settings"; label: "Движок"; value: root.engineName }
            RowSep {}
            InfoRow { icon: "folder"; label: "Конфиг"; value: root.configPath }
            RowSep {}
            InfoRow { icon: "flag"; label: "Лицензия"; value: root.licenseName }
        }
    }

    // компактная инфо-строка: иконка 28×28 на bgTrack, подпись и значение
    component InfoRow: Rectangle {
        id: infoRow

        property string icon: ""
        property string label: ""
        property string value: ""

        implicitHeight: Theme.dp(34)
        Layout.fillWidth: true
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: Theme.dp(6)

            Rectangle { // контейнер иконки
                implicitWidth: Theme.dp(28)
                implicitHeight: Theme.dp(28)
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
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }

            Text { // значение; длинные имена CPU/GPU обрезаются
                Layout.maximumWidth: Theme.dp(170)
                elide: Text.ElideRight
                text: infoRow.value
                color: Theme.text
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium")
            }
        }
    }

    // разделитель вровень с текстом (после контейнера иконки)
    component RowSep: Divider {
        Layout.fillWidth: true
        leftInset: Theme.dp(38)
    }

    // мини-чип метаданных: labelSmall на bgTrack
    component MiniChip: Rectangle {
        id: chip

        property string text: ""

        implicitWidth: chipText.implicitWidth + Theme.dp(18)
        implicitHeight: Theme.dp(22)
        radius: Theme.radiusPill
        color: Theme.bgTrack

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }
    }
}
