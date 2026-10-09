import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
import ".."

ColumnLayout {
    id: volumePage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "volume"
    Layout.fillWidth: true; spacing: 10

    // общая громкость: клик по иконке — mute
    SliderRow {
        Layout.fillWidth: true
        icon: (win && win.sink && win.sink.audio.muted) ? "volume_off" : "volume_up"
        value: win && win.sink ? win.sink.audio.volume : 0
        onMoved: (v) => { if (win.sink) win.sink.audio.volume = v; }
        onIconClicked: { if (win.sink) win.sink.audio.muted = !win.sink.audio.muted; }
    }

    Text {
        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("labelMedium")
        font.weight: Theme.typeWeight("labelMedium"); color: Theme.subtext
        text: "Вывод звука"
    }
    Repeater {
        model: win ? win.outputs : []
        delegate: DeviceRow {
            required property var modelData
            Layout.fillWidth: true
            devName: modelData.description || modelData.name
            selected: win.sink && win.sink.id === modelData.id
            onClicked: Sys.setDefaultAudio(modelData.id)
        }
    }

    Text {
        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("labelMedium")
        font.weight: Theme.typeWeight("labelMedium"); color: Theme.subtext
        text: "Микрофон"
    }
    Repeater {
        model: win ? win.inputs : []
        delegate: DeviceRow {
            required property var modelData
            Layout.fillWidth: true
            devName: modelData.description || modelData.name
            selected: win.source && win.source.id === modelData.id
            onClicked: Sys.setDefaultAudio(modelData.id)
        }
    }

    Text {
        visible: win && win.streams.length > 0
        Layout.topMargin: Theme.dp(4)
        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("labelMedium")
        font.weight: Theme.typeWeight("labelMedium"); color: Theme.subtext
        text: "Приложения"
    }
    Repeater {
        model: win ? win.streams : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: Theme.dp(10)
            Text {
                Layout.preferredWidth: Theme.dp(120); elide: Text.ElideRight
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyMedium")
                font.weight: Theme.typeWeight("bodyMedium"); color: Theme.text
                text: modelData.description || modelData.name
            }
            Slider {
                Layout.fillWidth: true
                value: modelData.audio.volume
                onMoved: (v) => Sys.setStreamVolume(modelData.id, v)
                onCommitted: (v) => Sys.setStreamVolume(modelData.id, v)
            }
            Text {
                Layout.preferredWidth: Theme.dp(34); horizontalAlignment: Text.AlignRight
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
                text: Math.round(modelData.audio.volume * 100) + "%"
            }
        }
    }
}
