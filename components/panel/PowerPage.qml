import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."

ColumnLayout {
    id: powerPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "power"
    Layout.fillWidth: true; spacing: 8
    PowerRow { Layout.fillWidth: true; icon: "\uf023"; label: "Заблокировать"; onClicked: if (win.shell) win.shell.lock() }
    PowerRow { Layout.fillWidth: true; icon: "\uf2f5"; label: "Выйти"; onClicked: Sys.logout() }
    PowerRow { Layout.fillWidth: true; icon: "\uf186"; label: "Спящий режим"; onClicked: Sys.suspend() }
    PowerRow { Layout.fillWidth: true; icon: "\uf021"; label: "Перезагрузка"; onClicked: Sys.reboot() }
    PowerRow { Layout.fillWidth: true; icon: "\uf011"; label: "Выключение"; onClicked: Sys.poweroff() }
}
