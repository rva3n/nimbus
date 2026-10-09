import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."

ColumnLayout {
    id: clipboardPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "clipboard"
    Layout.fillWidth: true; spacing: 8

    RowLayout {
        Layout.fillWidth: true
        Text { font.family: Theme.font; font.pixelSize: 12; color: Theme.subtext; Layout.fillWidth: true; text: "История" }
        Text { visible: Clip.loading; font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "загрузка…" }
        IconBtn { glyph: "\uf021"; onClicked: Clip.refresh() }
        IconBtn { glyph: "\uf1f8"; onClicked: Clip.wipe() }
    }

    Text {
        visible: Clip.pins.length > 0
        font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Закреплённые"
    }
    Repeater {
        model: Clip.pins
        delegate: ClipRow {
            required property var modelData
            Layout.fillWidth: true
            item: modelData
            pinned: true
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: 360
        model: Clip.items
        clip: true; spacing: 2
        delegate: ClipRow {
            required property var modelData
            width: ListView.view.width
            item: modelData
        }
    }
}
