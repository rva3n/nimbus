import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui"

// Корневая страница панели: плитки быстрых настроек, медиа-карточка и уведомления.
ColumnLayout {
    id: rootPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === ""
    Layout.fillWidth: true
    spacing: 14

    GridLayout { // плитки быстрых настроек
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 8
        rowSpacing: 8

        Tile { icon: "wifi"; label: "Wi-Fi"; active: Sys.wifiEnabled; onTapped: if (win.shell) { Sys.refreshWifi(); win.shell.togglePage("wifi"); } }
        Tile { icon: "bluetooth"; label: "Bluetooth"; active: Sys.btEnabled; onTapped: if (win.shell) { Sys.startBtScan(); win.shell.togglePage("bluetooth"); } }
        Tile { icon: "volume_up"; label: "Звук"; onTapped: if (win.shell) win.shell.togglePage("volume") }
        Tile { icon: "brightness_6"; label: "Яркость"; onTapped: if (win.shell) win.shell.togglePage("brightness") }
        Tile { icon: "do_not_disturb_on"; label: "DND"; active: Notif.dnd; onTapped: Notif.dnd = !Notif.dnd }
        Tile { icon: "image"; label: "Обои"; onTapped: if (win.shell) win.shell.togglePage("wallpapers") }
    }

    // Медиа-карточка — отдельный компонент; props не меняем.
    MediaCard {
        visible: win && win.player !== null
        Layout.fillWidth: true
        artFile: win ? win.artFile : ""
        artUrl: win ? win.artUrl : ""
        player: win ? win.player : null
    }

    RowLayout { // заголовок уведомлений
        visible: win && Notif.history.length > 0
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "Уведомления"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelMedium")
            font.weight: Theme.typeWeight("labelMedium")
        }

        IconButton {
            icon: "delete"
            size: "s"
            onClicked: Notif.clearAll()
        }
    }

    Repeater {
        model: win ? Notif.history.slice(0, 3) : []

        delegate: NotifItem {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            item: modelData
            itemIndex: index
        }
    }
}
