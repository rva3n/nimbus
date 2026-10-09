import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui"

// Буфер обмена: история и закреплённые записи.
ColumnLayout {
    id: clipboardPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "clipboard"
    Layout.fillWidth: true
    spacing: 8

    RowLayout { // заголовок + действия
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "История"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelMedium")
            font.weight: Theme.typeWeight("labelMedium")
        }

        Text {
            visible: Clip.loading
            Layout.alignment: Qt.AlignVCenter
            text: "загрузка…"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }

        IconButton {
            icon: "refresh"
            size: "s"
            onClicked: Clip.refresh()
        }

        IconButton {
            icon: "delete"
            size: "s"
            onClicked: Clip.wipe()
        }
    }

    Text {
        visible: Clip.pins.length > 0
        text: "Закреплённые"
        color: Theme.subtext
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelMedium")
        font.weight: Theme.typeWeight("labelMedium")
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
        clip: true
        spacing: 4

        delegate: ClipRow {
            required property var modelData
            width: ListView.view.width
            item: modelData
        }
    }
}
