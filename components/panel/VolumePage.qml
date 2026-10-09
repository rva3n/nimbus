import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."

ColumnLayout {
    id: volumePage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "volume"
    Layout.fillWidth: true; spacing: 10
    SliderRow {
        Layout.fillWidth: true
        icon: (win && win.sink && win.sink.audio.muted) ? "\uf026" : "\uf028"
        value: win && win.sink ? win.sink.audio.volume : 0
        onMoved: (v) => { if (win.sink) win.sink.audio.volume = v; }
        onIconClicked: { if (win.sink) win.sink.audio.muted = !win.sink.audio.muted; }
    }
    Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Вывод звука" }
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
    Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Микрофон" }
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
        Layout.topMargin: 4
        font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Приложения"
    }
    Repeater {
        model: win ? win.streams : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 8
            Text {
                Layout.preferredWidth: 120; elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: 11; color: Theme.text
                text: modelData.description || modelData.name
            }
            Item {
                Layout.fillWidth: true; implicitHeight: 22
                Rectangle {
                    id: strk
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3; color: Theme.surfaceHi
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, modelData.audio.volume))
                        height: parent.height; radius: 3; color: Theme.accent
                    }
                }
                MouseArea {
                    anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6
                    onPressed: (m) => Sys.setStreamVolume(modelData.id, Math.max(0, Math.min(1, m.x / strk.width)))
                    onPositionChanged: (m) => Sys.setStreamVolume(modelData.id, Math.max(0, Math.min(1, m.x / strk.width)))
                }
            }
            Text {
                Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
                font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext
                text: Math.round(modelData.audio.volume * 100) + "%"
            }
        }
    }
}
