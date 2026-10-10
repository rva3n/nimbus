import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Диспетчер задач: шапка с вкладками «Диспетчер / Монитор / Система» и
// содержимое выбранной вкладки. Закрытие — кнопка справа (shell.closeOverlays).
ColumnLayout {
    id: tm

    property var shell: null
    property int tab: 0

    Layout.fillWidth: true
    spacing: Theme.dp(10)

    // ── Шапка: вкладки слева, закрытие справа ─────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(8)

        Chip {
            Layout.alignment: Qt.AlignVCenter
            label: "Диспетчер"
            icon: "dashboard"
            selected: tm.tab === 0
            onClicked: tm.tab = 0
        }

        Chip {
            Layout.alignment: Qt.AlignVCenter
            label: "Монитор"
            icon: "monitor_heart"
            selected: tm.tab === 1
            onClicked: tm.tab = 1
        }

        Chip {
            Layout.alignment: Qt.AlignVCenter
            label: "Система"
            icon: "info"
            selected: tm.tab === 2
            onClicked: tm.tab = 2
        }

        Item { Layout.fillWidth: true }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "close"
            onClicked: if (tm.shell) tm.shell.closeOverlays()
        }
    }

    // ── Содержимое вкладок ────────────────────────────────────────────
    ProcessesTab {
        visible: tm.tab === 0
        shell: tm.shell
    }

    MonitorTab { visible: tm.tab === 1 }

    AboutTab { visible: tm.tab === 2 }
}
