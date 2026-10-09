import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."

// Root panel page: quick tiles, media card, recent notifications.
ColumnLayout {
    id: rootPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === ""
    Layout.fillWidth: true
    spacing: 14

    GridLayout {
        Layout.fillWidth: true
        columns: 4; columnSpacing: 8; rowSpacing: 8
        Tile { icon: "\uf1eb"; label: "Wi-Fi"; active: Sys.wifiEnabled; onTapped: if (win.shell) { Sys.refreshWifi(); win.shell.togglePage("wifi"); } }
        Tile { icon: "\uf293"; label: "Bluetooth"; active: Sys.btEnabled; onTapped: if (win.shell) { Sys.startBtScan(); win.shell.togglePage("bluetooth"); } }
        Tile { icon: "\uf028"; label: "Звук"; onTapped: if (win.shell) win.shell.togglePage("volume") }
        Tile { icon: "\uf185"; label: "Яркость"; onTapped: if (win.shell) win.shell.togglePage("brightness") }
        Tile { icon: "\uf0f3"; label: "DND"; active: Notif.dnd; onTapped: Notif.dnd = !Notif.dnd }
        Tile { icon: "\uf03e"; label: "Обои"; onTapped: if (win.shell) win.shell.togglePage("wallpapers") }
    }

    MediaCard {
        visible: win && win.player !== null
        Layout.fillWidth: true
        artFile: win ? win.artFile : ""
        artUrl: win ? win.artUrl : ""
        player: win ? win.player : null
    }

    RowLayout {
        visible: win && Notif.history.length > 0
        Layout.fillWidth: true
        Text { font.family: Theme.font; font.pixelSize: 12; color: Theme.subtext; Layout.fillWidth: true; text: "Уведомления" }
        IconBtn { glyph: "\uf1f8"; onClicked: Notif.clearAll() }
    }
    Repeater {
        model: win ? Notif.history.slice(0, 3) : []
        delegate: NotifItem { required property var modelData; required property int index; Layout.fillWidth: true; item: modelData; itemIndex: index }
    }
}
