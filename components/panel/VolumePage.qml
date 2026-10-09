import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"
import ".."

// Звук: общая громкость и карточки вывода/ввода и приложений.
ColumnLayout {
    id: volumePage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "volume"
    Layout.fillWidth: true; spacing: 10

    // общая громкость: клик по иконке — mute
    Card {
        Layout.fillWidth: true
        pad: Theme.dp(6)

        SliderRow {
            Layout.fillWidth: true
            icon: (win && win.sink && win.sink.audio.muted) ? "volume_off" : "volume_up"
            value: win && win.sink ? win.sink.audio.volume : 0
            onMoved: (v) => { if (win.sink) win.sink.audio.volume = v; }
            onIconClicked: { if (win.sink) win.sink.audio.muted = !win.sink.audio.muted; }
        }
    }

    // устройства вывода звука
    Card {
        Layout.fillWidth: true
        title: "Вывод звука"

        Repeater {
            model: win ? win.outputs : []
            delegate: ColumnLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0

                Divider { Layout.fillWidth: true; leftInset: Theme.dp(56); visible: index > 0 }
                DeviceRow {
                    Layout.fillWidth: true
                    icon: "volume_up"
                    devName: modelData.description || modelData.name
                    selected: !!(win && win.sink && win.sink.id === modelData.id)
                    onClicked: Sys.setDefaultAudio(modelData.id)
                }
            }
        }
    }

    // устройства ввода
    Card {
        Layout.fillWidth: true
        title: "Микрофон"

        Repeater {
            model: win ? win.inputs : []
            delegate: ColumnLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0

                Divider { Layout.fillWidth: true; leftInset: Theme.dp(56); visible: index > 0 }
                DeviceRow {
                    Layout.fillWidth: true
                    icon: "mic"
                    devName: modelData.description || modelData.name
                    selected: !!(win && win.source && win.source.id === modelData.id)
                    onClicked: Sys.setDefaultAudio(modelData.id)
                }
            }
        }
    }

    // громкость отдельных приложений
    Card {
        visible: win !== null && win.streams.length > 0
        Layout.fillWidth: true
        title: "Приложения"

        Repeater {
            model: win ? win.streams : []
            delegate: ColumnLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0

                Divider { Layout.fillWidth: true; leftInset: Theme.dp(56); visible: index > 0 }
                RowLayout { // строка приложения
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.dp(56)
                    Layout.leftMargin: Theme.dp(8); Layout.rightMargin: Theme.dp(8)
                    spacing: Theme.dp(8)

                    Rectangle { // ведущая иконка приложения 40×40
                        implicitWidth: Theme.dp(40); implicitHeight: Theme.dp(40)
                        radius: Theme.radiusMd
                        color: Theme.bgTrack

                        Icon {
                            anchors.centerIn: parent
                            name: "graphic_eq"; size: Theme.dp(20)
                            color: Theme.subtext
                        }
                    }
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
    }
}
