import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Система»: кольца CPU/RAM/GPU/диск из SysStats и справка «О системе».
ColumnLayout {
    id: page
    property var win: null
    Layout.fillWidth: true
    spacing: Theme.dp(10)
    visible: win !== null && win.mode === "panel" && win.page === "" && win.shell && win.shell.panelTab === "system"

    // байты → «N.N ГБ»
    function fmtGb(bytes) {
        if (!bytes || bytes <= 0) return "—";
        return (bytes / 1073741824).toFixed(1) + " ГБ";
    }
    // секунды → «N ч M мин»
    function fmtUptime(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }
    // цвет кольца по порогам нагрузки (CPU/GPU)
    function cpuColor(v) { return v > 0.8 ? Theme.error : (v > 0.6 ? Theme.warning : Theme.accent) }

    // строка справки: ведущая иконка 40×40, подпись, значение
    component InfoRow: Rectangle {
        id: infoRow
        property string icon: ""
        property string label: ""
        property string value: ""
        implicitHeight: Theme.dp(48)
        // строка растягивается по ширине карточки (иначе RowLayout схлопывается)
        Layout.fillWidth: true
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(8); anchors.rightMargin: Theme.dp(8)
            spacing: Theme.dp(8)

            Rectangle { // ведущая иконка 40×40
                implicitWidth: Theme.dp(40); implicitHeight: Theme.dp(40)
                radius: Theme.radiusMd
                color: Theme.bgTrack

                Icon {
                    anchors.centerIn: parent
                    name: infoRow.icon
                    size: Theme.dp(20)
                    color: Theme.subtext
                }
            }
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
                font.weight: Theme.typeWeight("bodyLarge"); color: Theme.text
                text: infoRow.label
            }
            Text {
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium"); color: Theme.subtext
                text: infoRow.value
            }
        }
    }

    // верх: живые метрики, заголовок — имя хоста
    Card {
        Layout.fillWidth: true
        title: SysStats.host

        RowLayout { // кольца метрик: 4 уменьшены до 76px, чтобы влезли в ряд
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.dp(10)

            Item { Layout.fillWidth: true }

            Ring {
                Layout.preferredWidth: Theme.dp(76)
                Layout.preferredHeight: Theme.dp(76)
                value: SysStats.cpu
                label: Math.round(SysStats.cpu * 100) + "%"
                caption: "CPU"
                color: page.cpuColor(SysStats.cpu)
            }
            Ring {
                Layout.preferredWidth: Theme.dp(76)
                Layout.preferredHeight: Theme.dp(76)
                value: SysStats.memFrac
                label: Math.round(SysStats.memFrac * 100) + "%"
                caption: "RAM"
            }
            Ring {
                Layout.preferredWidth: Theme.dp(76)
                Layout.preferredHeight: Theme.dp(76)
                value: SysStats.gpuBusy
                label: Math.round(SysStats.gpuBusy * 100) + "%"
                caption: "GPU"
                color: page.cpuColor(SysStats.gpuBusy)
            }
            Ring {
                Layout.preferredWidth: Theme.dp(76)
                Layout.preferredHeight: Theme.dp(76)
                value: SysStats.diskFrac
                label: Math.round(SysStats.diskFrac * 100) + "%"
                caption: "Диск"
            }

            Item { Layout.fillWidth: true }
        }

        // температура, если есть датчик
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(2)
            Layout.leftMargin: Theme.dp(8); Layout.rightMargin: Theme.dp(8)
            visible: SysStats.tempC > 0
            spacing: Theme.dp(8)

            Rectangle { // ведущая иконка 40×40
                implicitWidth: Theme.dp(40); implicitHeight: Theme.dp(40)
                radius: Theme.radiusMd
                color: Theme.bgTrack

                Icon {
                    anchors.centerIn: parent
                    name: "device_thermostat"; size: Theme.dp(20)
                    color: Theme.subtext
                }
            }
            Text {
                Layout.fillWidth: true
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
                font.weight: Theme.typeWeight("bodyLarge"); color: Theme.text
                text: "Температура: " + Math.round(SysStats.tempC) + "°C"
            }
        }
    }

    // справка о системе
    Card {
        Layout.fillWidth: true
        title: "О системе"

        InfoRow { icon: "memory"; label: "Хост"; value: SysStats.host }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56) }
        InfoRow { icon: "monitor_heart"; label: "Ядро"; value: SysStats.kernel }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56) }
        InfoRow { icon: "hourglass_top"; label: "Время работы"; value: page.fmtUptime(SysStats.uptime) }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56); visible: SysStats.tempC > 0 }
        InfoRow {
            visible: SysStats.tempC > 0
            icon: "device_thermostat"; label: "Температура"
            value: Math.round(SysStats.tempC) + "°C"
        }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56) }
        InfoRow {
            icon: "memory"; label: "Память"
            value: page.fmtGb(SysStats.memUsed) + " / " + page.fmtGb(SysStats.memTotal)
        }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56) }
        InfoRow {
            icon: "storage"; label: "Диск"
            value: page.fmtGb(SysStats.diskUsed) + " / " + page.fmtGb(SysStats.diskTotal)
        }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56); visible: SysStats.vramTotal > 0 }
        InfoRow {
            visible: SysStats.vramTotal > 0
            icon: "developer_board"; label: "VRAM"
            value: page.fmtGb(SysStats.vramUsed) + " / " + page.fmtGb(SysStats.vramTotal)
        }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56); visible: SysStats.gpuTempC > 0 }
        InfoRow {
            visible: SysStats.gpuTempC > 0
            icon: "device_thermostat"; label: "GPU-темп."
            value: Math.round(SysStats.gpuTempC) + " °C"
        }
        Divider { Layout.fillWidth: true; leftInset: Theme.dp(56); visible: SysStats.gpuPowerW >= 0 }
        InfoRow {
            visible: SysStats.gpuPowerW >= 0
            icon: "power"; label: "GPU"
            value: Math.round(SysStats.gpuPowerW) + " Вт"
        }
    }
}
