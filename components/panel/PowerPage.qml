import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui"

// Питание: одна Card, строки PowerRow с разделителями.
ColumnLayout {
    id: powerPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "power"
    Layout.fillWidth: true
    spacing: Theme.dp(10)

    Card {
        Layout.fillWidth: true
        title: "Питание"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(4)

            PowerRow { Layout.fillWidth: true; icon: "lock"; label: "Заблокировать"; onClicked: if (win.shell) win.shell.lock() }

            PowerRow { Layout.fillWidth: true; icon: "logout"; label: "Выйти"; onClicked: Sys.logout() }

            PowerRow { Layout.fillWidth: true; icon: "bedtime"; label: "Спящий режим"; onClicked: Sys.suspend() }

            PowerRow { Layout.fillWidth: true; icon: "restart_alt"; label: "Перезагрузка"; onClicked: Sys.reboot() }

            PowerRow { Layout.fillWidth: true; icon: "power_settings_new"; label: "Выключение"; danger: true; onClicked: Sys.poweroff() }
        }
    }
}
