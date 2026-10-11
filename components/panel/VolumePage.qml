pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Звук: общая громкость и карточки вывода/ввода и приложений.
ColumnLayout {
    id: volumePage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "volume"
    Layout.fillWidth: true; spacing: 10

    // application.name (lowercase) → имя иконки; тот же приём, что и в
    // WorkspacesRow/Switcher, плюс сопоставление по Name десктоп-файла, потому
    // что PipeWire отдаёт человекочитаемое имя приложения.
    readonly property var iconIndex: {
        const byId = {};
        const byClass = {};
        const byName = {};
        for (const e of DesktopEntries.applications.values) {
            if (!e.icon) continue;
            if (e.id) byId[String(e.id).toLowerCase()] = e.icon;
            if (e.startupClass) byClass[String(e.startupClass).toLowerCase()] = e.icon;
            if (e.name) byName[String(e.name).toLowerCase()] = e.icon;
        }
        return { byId: byId, byClass: byClass, byName: byName };
    }

    function iconFor(n) {
        if (!n) return "";
        const p = n.properties || {};
        const direct = p["application.icon.name"];
        if (direct) {
            const dp = Quickshell.iconPath(String(direct), true);
            if (dp !== "") return dp;
        }
        const ix = volumePage.iconIndex;
        const keys = [p["application.name"], p["application.process.binary"],
                      n.description, n.name];
        for (const raw of keys) {
            const k = String(raw || "").toLowerCase();
            if (k === "") continue;
            const nm = ix.byId[k] || ix.byClass[k] || ix.byName[k];
            if (nm) {
                const path = Quickshell.iconPath(nm, true);
                if (path !== "") return path;
            }
        }
        return "";
    }

    function streamName(n) {
        if (!n) return "";
        const p = n.properties || {};
        return p["application.name"] || n.description || n.name || "";
    }

    // playback-потоки: isStream && isSink; capture-потоки: isStream && !isSink
    readonly property var playbackStreams: {
        const out = [];
        const ss = volumePage.win ? volumePage.win.streams : null;
        if (!ss) return out;
        for (const n of ss) if (n.isSink) out.push(n);
        return out;
    }
    readonly property var captureStreams: {
        const out = [];
        const ss = volumePage.win ? volumePage.win.streams : null;
        if (!ss) return out;
        for (const n of ss) if (!n.isSink) out.push(n);
        return out;
    }

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

    // громкость воспроизводящих приложений (playback: isStream && isSink)
    Card {
        visible: volumePage.playbackStreams.length > 0
        Layout.fillWidth: true
        title: "Приложения"

        Repeater {
            model: volumePage.playbackStreams
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

                    Rectangle { // иконка приложения 40×40, внутри AppIcon 20 / глиф
                        readonly property string iconPath: volumePage.iconFor(modelData)
                        implicitWidth: Theme.dp(40); implicitHeight: Theme.dp(40)
                        radius: Theme.radiusMd
                        color: Theme.bgTrack

                        Icon {
                            anchors.centerIn: parent
                            visible: parent.iconPath === ""
                            name: "graphic_eq"; size: Theme.dp(20)
                            color: Theme.subtext
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            visible: parent.iconPath !== ""
                            source: parent.iconPath
                            size: 20
                        }
                    }
                    Text {
                        Layout.preferredWidth: Theme.dp(100); elide: Text.ElideRight
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyMedium")
                        font.weight: Theme.typeWeight("bodyMedium"); color: Theme.text
                        text: volumePage.streamName(modelData)
                    }
                    Slider {
                        Layout.fillWidth: true
                        value: modelData.audio ? modelData.audio.volume : 0
                        onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v; }
                        onCommitted: (v) => { if (modelData.audio) modelData.audio.volume = v; }
                    }
                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        size: "s"
                        icon: (modelData.audio && modelData.audio.muted) ? "volume_off" : "volume_up"
                        onClicked: { if (modelData.audio) modelData.audio.muted = !modelData.audio.muted; }
                    }
                    Text {
                        Layout.preferredWidth: Theme.dp(34); horizontalAlignment: Text.AlignRight
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
                        text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "0%"
                    }
                }
            }
        }
    }

    // громкость захватывающих приложений (capture: isStream && !isSink)
    Card {
        visible: volumePage.captureStreams.length > 0
        Layout.fillWidth: true
        title: "Микрофоны"

        Repeater {
            model: volumePage.captureStreams
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

                    Rectangle { // иконка приложения 40×40, внутри AppIcon 20 / глиф
                        readonly property string iconPath: volumePage.iconFor(modelData)
                        implicitWidth: Theme.dp(40); implicitHeight: Theme.dp(40)
                        radius: Theme.radiusMd
                        color: Theme.bgTrack

                        Icon {
                            anchors.centerIn: parent
                            visible: parent.iconPath === ""
                            name: "graphic_eq"; size: Theme.dp(20)
                            color: Theme.subtext
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            visible: parent.iconPath !== ""
                            source: parent.iconPath
                            size: 20
                        }
                    }
                    Text {
                        Layout.preferredWidth: Theme.dp(100); elide: Text.ElideRight
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyMedium")
                        font.weight: Theme.typeWeight("bodyMedium"); color: Theme.text
                        text: volumePage.streamName(modelData)
                    }
                    Slider {
                        Layout.fillWidth: true
                        value: modelData.audio ? modelData.audio.volume : 0
                        onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v; }
                        onCommitted: (v) => { if (modelData.audio) modelData.audio.volume = v; }
                    }
                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        size: "s"
                        icon: (modelData.audio && modelData.audio.muted) ? "volume_off" : "volume_up"
                        onClicked: { if (modelData.audio) modelData.audio.muted = !modelData.audio.muted; }
                    }
                    Text {
                        Layout.preferredWidth: Theme.dp(34); horizontalAlignment: Text.AlignRight
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
                        text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "0%"
                    }
                }
            }
        }
    }
}
