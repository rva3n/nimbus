import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Диспетчер задач: шапка с вкладками «Диспетчер / Монитор / Система» и
// содержимое выбранной вкладки. Закрытие — кнопка справа (shell.closeOverlays).
ColumnLayout {
    id: tm

    property var shell: null
    property int initialTab: 0
    property int tab: 0

    // при открытии — на вкладку, запрошенную извне (IPC/кейбинд)
    onVisibleChanged: if (visible) {
        tab = initialTab;
        if (tm.shell)
            tm.shell.taskmanTab = tab;
    }

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
            onClicked: { tm.tab = 0; if (tm.shell) tm.shell.taskmanTab = 0; }
        }

        Chip {
            Layout.alignment: Qt.AlignVCenter
            label: "Монитор"
            icon: "monitor_heart"
            selected: tm.tab === 1
            onClicked: { tm.tab = 1; if (tm.shell) tm.shell.taskmanTab = 1; }
        }

        Chip {
            Layout.alignment: Qt.AlignVCenter
            label: "Система"
            icon: "info"
            selected: tm.tab === 2
            onClicked: { tm.tab = 2; if (tm.shell) tm.shell.taskmanTab = 2; }
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

    // ESC закрывает диспетчер
    focus: visible
    Keys.onEscapePressed: if (tm.shell) tm.shell.closeOverlays()
}
