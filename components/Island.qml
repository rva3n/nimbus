import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import "../core"

// Nimbus island. The Wayland surface is a fixed-size transparent band; the pill
// inside it is animated in QML (smooth). Input is limited to the pill via mask.
PanelWindow {
    id: win
    required property var modelData
    property var shell: null
    property string view: "idle"        // idle | panel | launcher

    screen: modelData
    color: "transparent"
    anchors { top: true; left: true; right: true }
    exclusiveZone: 0
    implicitHeight: 664
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nimbus-island"
    WlrLayershell.keyboardFocus: (view === "launcher" || view === "panel")
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: pill; radius: pill.radius }

    readonly property string mode: (Notif.visible && view === "idle") ? "notif"
                                 : (Osd.visible && view === "idle") ? "osd" : view
    readonly property bool big: mode === "panel" || mode === "launcher"
    readonly property string page: win.shell ? win.shell.panelPage : ""

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: win.now = new Date() }

    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0) return null;
        for (const p of ps) if (p.isPlaying) return p;
        return ps[0];
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var battery: UPower.displayDevice
    readonly property bool showBattery: battery !== null && battery.isPresent
        && String(battery.iconName).indexOf("missing") === -1

    // PipeWire device lists
    readonly property var outputs: {
        const out = [];
        for (const n of Pipewire.nodes.values) if (n.isSink && !n.isStream && n.audio) out.push(n);
        return out;
    }
    readonly property var inputs: {
        const out = [];
        for (const n of Pipewire.nodes.values) if (!n.isSink && !n.isStream && n.audio) out.push(n);
        return out;
    }
    readonly property var streams: {
        const out = [];
        for (const n of Pipewire.nodes.values) if (n.isStream && n.audio) out.push(n);
        return out;
    }
    // Wi-Fi list (dedup + sort)
    readonly property var wifiList: {
        const seen = {}; const out = [];
        for (const n of Sys.wifiNetworks) {
            if (!n.ssid || seen[n.ssid]) continue;
            seen[n.ssid] = true; out.push(n);
        }
        out.sort((a, b) => b.signal - a.signal);
        return out.slice(0, 8);
    }

    function mediaIcon() { return (win.player && win.player.isPlaying) ? "\uf04c" : "\uf04b"; }
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    // Copy the (short-lived) player art into a stable cache file with extension.
    property string artSrc: ""
    property string artFile: ""
    Process {
        id: artProc
        command: ["sh", "-c",
            "src=" + shq(win.artUrl) + "; " +
            "case \"$src\" in file://*) p=\"${src#file://}\";; *) p=\"$src\";; esac; " +
            "if [ -f \"$p\" ]; then t=$(file -b --mime-type \"$p\" 2>/dev/null | sed 's#image/##'); [ \"$t\" = jpeg ] && t=jpg; " +
            "d=" + shq(Quickshell.cacheDir) + "/art.$t; cp -f \"$p\" \"$d\" && printf %s \"$d\"; fi"]
        stdout: SplitParser { onRead: line => win.artFile = line.trim() }
    }
    Timer {
        interval: 1500; running: true; repeat: true
        onTriggered: if (win.artUrl !== win.artSrc) { win.artSrc = win.artUrl; artProc.running = false; artProc.running = true; }
    }
    readonly property string artUrl: {
        const p = win.player;
        if (!p) return "";
        let u = p.trackArtUrl || "";
        if ((u === "" || u === undefined) && p.metadata) u = p.metadata["mpris:artUrl"] || "";
        if (u && u.indexOf("://") === -1) u = "file://" + u;
        return u;
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 6
        width: win.big ? (win.mode === "launcher" ? 470 : 404) : (holder.implicitWidth + Theme.pad * 2)
        height: win.big ? Math.min(contentCol.implicitHeight + 32, 652) : Theme.height
        radius: win.big ? 26 : height / 2
        color: Theme.a(Theme.bg, 0.97)
        border.width: 1
        border.color: Theme.a(Theme.outline, 0.6)
        clip: true
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // ── IDLE / OSD / NOTIF ───────────────────────────────────────
        Item {
            id: holder
            visible: !win.big
            anchors.centerIn: parent
            implicitWidth: win.mode === "notif" ? notifRow.implicitWidth
                         : win.mode === "osd" ? osdRow.implicitWidth
                         : compactRow.implicitWidth
            implicitHeight: 22

            RowLayout {
                id: compactRow
                visible: win.mode === "idle"
                anchors.centerIn: parent
                spacing: Theme.spacing
                WorkspacesRow { output: win.screen.name }
                Text {
                    font.family: Theme.font; font.pixelSize: Theme.fontSize; color: Theme.text
                    text: Qt.formatDateTime(win.now, "HH:mm")
                }
                IconBtn { glyph: "\uf0f3"; onClicked: if (win.shell) win.shell.togglePanel() }
            }
            RowLayout {
                id: osdRow
                visible: win.mode === "osd"
                anchors.centerIn: parent
                spacing: 10
                Text {
                    font.family: Theme.font; font.pixelSize: 14; color: Theme.accent
                    text: Osd.kind === "volume" ? (Osd.muted ? "\uf026" : "\uf028") : "\uf185"
                }
                Rectangle {
                    Layout.preferredWidth: 150; Layout.preferredHeight: 8; radius: 4
                    color: Theme.surfaceHi
                    Rectangle {
                        width: (Osd.muted && Osd.kind === "volume") ? 0 : parent.width * Osd.value
                        height: parent.height; radius: 4; color: Theme.accent
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }
                Text {
                    font.family: Theme.font; font.pixelSize: 12; color: Theme.text
                    text: (Osd.muted && Osd.kind === "volume") ? "mute" : Math.round(Osd.value * 100) + "%"
                }
            }
            RowLayout {
                id: notifRow
                visible: win.mode === "notif"
                anchors.centerIn: parent
                spacing: 10
                Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.accent; text: "\uf0f3" }
                ColumnLayout {
                    spacing: 0; Layout.maximumWidth: 300
                    Text {
                        font.family: Theme.font; font.pixelSize: 12; color: Theme.text
                        text: Notif.current ? ((Notif.current.appName ? Notif.current.appName + " · " : "") + (Notif.current.summary || "")) : ""
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        visible: text !== ""
                        font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext
                        text: Notif.current ? (Notif.current.body || "") : ""
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
            }
        }

        // ── PANEL ────────────────────────────────────────────────────
        ColumnLayout {
            id: contentCol
            visible: win.big
            width: (win.mode === "launcher" ? 470 : 404) - 32
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 14

            // header
            RowLayout {
                Layout.fillWidth: true
                IconBtn {
                    glyph: "\uf060"; visible: win.mode === "panel" && win.page !== ""
                    onClicked: if (win.shell) win.shell.setPage("")
                }
                ColumnLayout {
                    spacing: 0
                    visible: win.mode === "panel" && win.page === ""
                    Text {
                        font.family: Theme.font; font.pixelSize: 22; font.bold: true; color: Theme.text
                        text: Qt.formatDateTime(win.now, "HH:mm")
                    }
                    Text {
                        font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext
                        text: win.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
                    }
                }
                Text {
                    visible: win.mode === "panel" && win.page !== ""
                    font.family: Theme.font; font.pixelSize: 18; font.bold: true; color: Theme.text
                    text: win.pageTitle
                }
                Item { Layout.fillWidth: true }
                IconBtn {
                    visible: win.mode === "panel"
                    glyph: "\uf011"
                    onClicked: if (win.shell) win.shell.setPage(win.page === "power" ? "" : "power")
                }
            }

            // ===== ROOT PAGE =====
            GridLayout {
                visible: win.mode === "panel" && win.page === ""
                Layout.fillWidth: true
                columns: 4; columnSpacing: 8; rowSpacing: 8
                Tile { icon: "\uf1eb"; label: "Wi-Fi"; active: Sys.wifiEnabled; onTapped: if (win.shell) { Sys.refreshWifi(); win.shell.togglePage("wifi"); } }
                Tile { icon: "\uf293"; label: "Bluetooth"; active: Sys.btEnabled; onTapped: if (win.shell) { Sys.startBtScan(); win.shell.togglePage("bluetooth"); } }
                Tile { icon: "\uf028"; label: "Звук"; onTapped: if (win.shell) win.shell.togglePage("volume") }
                Tile { icon: "\uf185"; label: "Яркость"; onTapped: if (win.shell) win.shell.togglePage("brightness") }
                Tile { icon: "\uf0f3"; label: "DND"; active: Notif.dnd; onTapped: Notif.dnd = !Notif.dnd }
                Tile { icon: "\uf03e"; label: "Обои"; onTapped: if (win.shell) win.shell.togglePage("wallpapers") }
            }

            MediaCard { visible: win.mode === "panel" && win.page === "" && win.player !== null; Layout.fillWidth: true }

            RowLayout {
                visible: win.mode === "panel" && win.page === "" && Notif.history.length > 0
                Layout.fillWidth: true
                Text { font.family: Theme.font; font.pixelSize: 12; color: Theme.subtext; Layout.fillWidth: true; text: "Уведомления" }
                IconBtn { glyph: "\uf1f8"; onClicked: Notif.clearAll() }
            }
            Repeater {
                model: (win.mode === "panel" && win.page === "") ? Notif.history.slice(0, 3) : []
                delegate: NotifItem { required property var modelData; required property int index; Layout.fillWidth: true; item: modelData; itemIndex: index }
            }

            // ===== WIFI PAGE =====
            ColumnLayout {
                visible: win.mode === "panel" && win.page === "wifi"
                Layout.fillWidth: true; spacing: 10
                ToggleRow {
                    Layout.fillWidth: true
                    label: "Wi-Fi"; sub: Sys.wifiEnabled ? "включён" : "выключен"
                    active: Sys.wifiEnabled
                    onToggled: { Sys.toggleWifi(); if (!Sys.wifiEnabled) Sys.refreshWifi(); }
                }
                Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Сети" }
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: win.wifiSel === "" ? 300 : 200
                    model: win.wifiList; clip: true; spacing: 2
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 40; radius: 10
                        color: wifiMouse.containsMouse ? Theme.surfaceHi : Theme.surface
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                            Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.text; text: modelData.ssid; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text {
                                visible: modelData.security && modelData.security !== "--" && modelData.security !== ""
                                font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "\uf023"
                            }
                            Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: modelData.signal + "%" }
                        }
                        MouseArea {
                            id: wifiMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                const sec = modelData.security;
                                if (!sec || sec === "" || sec === "--") {
                                    Sys.connectWifi(modelData.ssid, "");
                                    if (win.shell) win.shell.setPage("");
                                } else {
                                    win.wifiSel = modelData.ssid;
                                    wifiPassInput.text = "";
                                    wifiPassInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    visible: win.wifiSel !== ""
                    Layout.fillWidth: true; implicitHeight: 42; radius: 10
                    color: Theme.surface
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6; spacing: 8
                        TextInput {
                            id: wifiPassInput
                            Layout.fillWidth: true
                            font.family: Theme.font; font.pixelSize: 13; color: Theme.text
                            echoMode: TextInput.Password
                            clip: true; selectByMouse: true
                            onAccepted: win.submitWifi()
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: wifiPassInput.text === ""
                                text: "Пароль: " + win.wifiSel
                                color: Theme.a(Theme.subtext, 0.5); font: wifiPassInput.font
                            }
                        }
                        IconBtn { glyph: "\uf00c"; onClicked: win.submitWifi() }
                    }
                }
            }

            // ===== BLUETOOTH PAGE =====
            ColumnLayout {
                visible: win.mode === "panel" && win.page === "bluetooth"
                Layout.fillWidth: true; spacing: 10
                ToggleRow {
                    Layout.fillWidth: true
                    label: "Bluetooth"; sub: Sys.btEnabled ? "включён" : "выключен"
                    active: Sys.btEnabled
                    onToggled: { Sys.toggleBt(); if (!Sys.btEnabled) Sys.refreshBt(); }
                }
                Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Устройства" }
                ListView {
                    Layout.fillWidth: true; Layout.preferredHeight: 260
                    model: Sys.btDevices; clip: true; spacing: 2
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 40; radius: 10
                        color: Theme.surface
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.text; text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext; text: modelData.mac }
                        }
                    }
                }
                Text {
                    visible: Sys.btDevices.length === 0
                    font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext
                    text: "Устройств не найдено"
                }
            }

            // ===== VOLUME PAGE =====
            ColumnLayout {
                visible: win.mode === "panel" && win.page === "volume"
                Layout.fillWidth: true; spacing: 10
                SliderRow {
                    Layout.fillWidth: true
                    icon: (win.sink && win.sink.audio.muted) ? "\uf026" : "\uf028"
                    value: win.sink ? win.sink.audio.volume : 0
                    onMoved: (v) => { if (win.sink) win.sink.audio.volume = v; }
                    onIconClicked: { if (win.sink) win.sink.audio.muted = !win.sink.audio.muted; }
                }
                Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Вывод звука" }
                Repeater {
                    model: win.outputs
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
                    model: win.inputs
                    delegate: DeviceRow {
                        required property var modelData
                        Layout.fillWidth: true
                        devName: modelData.description || modelData.name
                        selected: win.source && win.source.id === modelData.id
                        onClicked: Sys.setDefaultAudio(modelData.id)
                    }
                }

                Text {
                    visible: win.streams.length > 0
                    Layout.topMargin: 4
                    font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "Приложения"
                }
                Repeater {
                    model: win.streams
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

            // ===== BRIGHTNESS PAGE =====
            ColumnLayout {
                visible: win.mode === "panel" && win.page === "brightness"
                Layout.fillWidth: true; spacing: 12
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: Theme.font; font.pixelSize: 40; font.bold: true; color: Theme.text
                    text: Math.round(Sys.brightnessFraction * 100) + "%"
                }
                SliderRow {
                    Layout.fillWidth: true
                    icon: "\uf185"
                    value: Sys.brightnessFraction
                    onMoved: (v) => { Sys.brightness = Math.round(v * Sys.brightnessMax); }
                    onCommitted: (v) => { Sys.setBrightnessPct(v * 100); }
                }
            }

            // ===== WALLPAPERS PAGE =====
            ColumnLayout {
                visible: win.mode === "panel" && win.page === "wallpapers"
                Layout.fillWidth: true; spacing: 10

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    TabBtn { label: "Фото"; active: Wallpaper.tab === "photos"; onClicked: { Wallpaper.tab = "photos"; if (Wallpaper.localItems.length === 0) Wallpaper.refreshLocal(); } }
                    TabBtn { label: "Видео"; active: Wallpaper.tab === "videos"; onClicked: { Wallpaper.tab = "videos"; if (Wallpaper.localItems.length === 0) Wallpaper.refreshLocal(); } }
                    TabBtn { label: "Motion"; active: Wallpaper.tab === "motion"; onClicked: { Wallpaper.tab = "motion"; if (Wallpaper.motionResults.length === 0) { Wallpaper.motionQuery = ""; Wallpaper.searchMotion(); } } }
                    TabBtn { label: "Wallhaven"; active: Wallpaper.tab === "wallhaven"; onClicked: { Wallpaper.tab = "wallhaven"; if (Wallpaper.results.length === 0) Wallpaper.search(); } }
                    Item { Layout.fillWidth: true }
                    Text { visible: Wallpaper.loading; font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "загрузка…" }
                    IconBtn { glyph: "\uf021"; onClicked: Wallpaper.tab === "wallhaven" ? Wallpaper.search() : Wallpaper.refreshLocal() }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Chip { label: Wallpaper.autoEnabled ? "Авто: вкл" : "Авто: выкл"; active: Wallpaper.autoEnabled; onClicked: { Wallpaper.autoEnabled = !Wallpaper.autoEnabled; Wallpaper.saveState(); } }
                    Chip { label: "Таймер: " + win.autoLabel; active: win.showAuto; onClicked: win.showAuto = !win.showAuto }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    visible: win.showAuto
                    Layout.fillWidth: true; spacing: 8
                    Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "1м" }
                    Item {
                        Layout.fillWidth: true; implicitHeight: 24
                        Rectangle {
                            id: atrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 6; radius: 3; color: Theme.surfaceHi
                            Rectangle {
                                width: parent.width * ((Wallpaper.autoMinutes - 1) / 1439)
                                height: parent.height; radius: 3; color: Theme.accent
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6
                            onPressed: (m) => win.setAuto(m.x / atrack.width)
                            onPositionChanged: (m) => win.setAuto(m.x / atrack.width)
                        }
                    }
                    Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "24ч" }
                    Text {
                        Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight
                        font.family: Theme.font; font.pixelSize: 11; color: Theme.text; text: win.autoLabel
                    }
                }

                TextInput {
                    visible: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
                    Layout.fillWidth: true; Layout.preferredHeight: 32
                    font.family: Theme.font; font.pixelSize: 14; color: Theme.text
                    clip: true; selectByMouse: true
                    onAccepted: {
                        if (Wallpaper.tab === "motion") { Wallpaper.motionQuery = text; Wallpaper.searchMotion(); }
                        else { Wallpaper.query = text; Wallpaper.search(); }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: parent.text === ""
                        text: Wallpaper.tab === "motion" ? "Поиск видео (MotionBGs)…" : "Поиск на Wallhaven…"
                        color: Theme.a(Theme.subtext, 0.5); font: parent.font
                    }
                }

                ColumnLayout {
                    visible: Wallpaper.tab === "wallhaven"
                    Layout.fillWidth: true; spacing: 6
                    RowLayout {
                        spacing: 6
                        Chip { label: "Топ"; active: Wallpaper.sorting === "toplist"; onClicked: { Wallpaper.sorting = "toplist"; Wallpaper.search(); } }
                        Chip { label: "Новые"; active: Wallpaper.sorting === "date_added"; onClicked: { Wallpaper.sorting = "date_added"; Wallpaper.search(); } }
                        Chip { label: "Случайные"; active: Wallpaper.sorting === "random"; onClicked: { Wallpaper.sorting = "random"; Wallpaper.search(); } }
                    }
                    RowLayout {
                        spacing: 6
                        Chip { label: "Общие"; active: Wallpaper.category === "general"; onClicked: { Wallpaper.category = "general"; Wallpaper.search(); } }
                        Chip { label: "Аниме"; active: Wallpaper.category === "anime"; onClicked: { Wallpaper.category = "anime"; Wallpaper.search(); } }
                        Chip { label: "Люди"; active: Wallpaper.category === "people"; onClicked: { Wallpaper.category = "people"; Wallpaper.search(); } }
                        Chip { label: "Все"; active: Wallpaper.category === "all"; onClicked: { Wallpaper.category = "all"; Wallpaper.search(); } }
                    }
                    RowLayout {
                        spacing: 6
                        Chip { label: "SFW"; active: Wallpaper.purity === "sfw"; onClicked: { Wallpaper.purity = "sfw"; Wallpaper.search(); } }
                        Chip { label: "18+"; active: Wallpaper.purity === "sketchy"; onClicked: { Wallpaper.purity = "sketchy"; Wallpaper.search(); } }
                        Chip { label: "FHD"; active: Wallpaper.minRes === "1920x1080"; onClicked: { Wallpaper.minRes = "1920x1080"; Wallpaper.search(); } }
                        Chip { label: "2K"; active: Wallpaper.minRes === "2560x1440"; onClicked: { Wallpaper.minRes = "2560x1440"; Wallpaper.search(); } }
                        Chip { label: "4K"; active: Wallpaper.minRes === "3840x2160"; onClicked: { Wallpaper.minRes = "3840x2160"; Wallpaper.search(); } }
                    }
                }

                GridView {
                    id: wpGrid
                    Layout.fillWidth: true
                    Layout.preferredHeight: 360
                    clip: true
                    cellWidth: 120; cellHeight: 84
                    onContentYChanged: if (Wallpaper.tab === "motion" && contentY + height >= contentHeight - 220) Wallpaper.loadMoreMotion()
                    model: Wallpaper.tab === "photos" ? Wallpaper.photos
                         : Wallpaper.tab === "videos" ? Wallpaper.videos
                         : Wallpaper.tab === "motion" ? Wallpaper.motionResults
                         : Wallpaper.results
                    delegate: Rectangle {
                        required property var modelData
                        width: 112; height: 76; radius: 10
                        color: Theme.surface; clip: true
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: (Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion") ? modelData.thumb : ("file://" + modelData.path)
                        }
                        Rectangle {
                            visible: Wallpaper.tab === "motion" || (Wallpaper.tab !== "wallhaven" && modelData.video)
                            anchors.fill: parent; color: Theme.a("#000000", 0.4)
                            Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: 20; color: Theme.text; text: "\uf03d" }
                        }
                        Rectangle {
                            visible: Wallpaper.tab !== "wallhaven" && Wallpaper.tab !== "motion" && Wallpaper.currentPath === modelData.path
                            anchors.fill: parent; radius: 10; color: "transparent"
                            border.width: 2; border.color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (Wallpaper.tab === "wallhaven") Wallpaper.applyUrl(modelData);
                                else if (Wallpaper.tab === "motion") Wallpaper.applyVideoUrl(modelData.video);
                                else Wallpaper.apply(modelData.path, modelData.video);
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: wpGrid.count === 0
                        font.family: Theme.font; font.pixelSize: 12; color: Theme.subtext
                        text: Wallpaper.loading ? "Загрузка…" : "Пусто"
                    }
                }

                RowLayout {
                    visible: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    Chip { label: "Ещё"; onClicked: Wallpaper.tab === "motion" ? Wallpaper.loadMoreMotion() : Wallpaper.nextPage() }
                }
            }

            // ===== CLIPBOARD PAGE =====
            ColumnLayout {
                visible: win.mode === "panel" && win.page === "clipboard"
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

            // ===== POWER PAGE =====
            ColumnLayout {
                visible: win.mode === "panel" && win.page === "power"
                Layout.fillWidth: true; spacing: 8
                PowerRow { Layout.fillWidth: true; icon: "\uf023"; label: "Заблокировать"; onClicked: if (win.shell) win.shell.lock() }
                PowerRow { Layout.fillWidth: true; icon: "\uf2f5"; label: "Выйти"; onClicked: Sys.logout() }
                PowerRow { Layout.fillWidth: true; icon: "\uf186"; label: "Спящий режим"; onClicked: Sys.suspend() }
                PowerRow { Layout.fillWidth: true; icon: "\uf021"; label: "Перезагрузка"; onClicked: Sys.reboot() }
                PowerRow { Layout.fillWidth: true; icon: "\uf011"; label: "Выключение"; onClicked: Sys.poweroff() }
            }

            // ===== LAUNCHER =====
            TextInput {
                id: search
                visible: win.mode === "launcher"
                Layout.fillWidth: true; Layout.preferredHeight: 34
                font.family: Theme.font; font.pixelSize: 18; color: Theme.text
                clip: true; selectByMouse: true
                focus: win.mode === "launcher"
                onTextChanged: win.query = text
                Keys.onEscapePressed: if (win.shell) win.shell.closeOverlays()
                Keys.onDownPressed: win.sel = Math.min(win.sel + 1, Math.max(0, win.apps.length - 1))
                Keys.onUpPressed: win.sel = Math.max(win.sel - 1, 0)
                Keys.onReturnPressed: win.launch(win.apps[win.sel])
                Keys.onEnterPressed: win.launch(win.apps[win.sel])
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Поиск приложений…"; color: Theme.a(Theme.subtext, 0.5); font: search.font
                }
            }
            RowLayout {
                visible: win.mode === "launcher"
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Chip {
                    label: "Скрытые (" + Apps.hidden.length + ")"
                    active: Apps.showHidden
                    onClicked: Apps.showHidden = !Apps.showHidden
                }
            }
            ListView {
                id: appList
                visible: win.mode === "launcher"
                Layout.fillWidth: true; Layout.preferredHeight: 400
                model: win.apps; clip: true; spacing: 2
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: appList.width; height: 46; radius: 10
                    color: index === win.sel ? Theme.a(Theme.accent, 0.15) : "transparent"
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: win.sel = index
                        onClicked: win.launch(modelData)
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 10
                        Image {
                            Layout.preferredWidth: 26; Layout.preferredHeight: 26
                            sourceSize.width: 26; sourceSize.height: 26
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.name || ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.comment || ""; visible: text !== ""; color: Theme.subtext; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Text {
                            visible: Apps.isPinned(modelData)
                            font.family: Theme.font; font.pixelSize: 11; color: Theme.accent; text: "\uf08d"
                        }
                        RoundBtn { glyph: "\uf08d"; active: Apps.isPinned(modelData); onClicked: Apps.togglePin(modelData) }
                        RoundBtn { glyph: Apps.isHidden(modelData) ? "\uf06e" : "\uf070"; active: Apps.isHidden(modelData); onClicked: Apps.toggleHide(modelData) }
                    }
                }
            }
        }
    }

    readonly property string pageTitle: page === "wifi" ? "Wi-Fi"
                                      : page === "bluetooth" ? "Bluetooth"
                                      : page === "volume" ? "Звук"
                                      : page === "brightness" ? "Яркость"
                                      : page === "power" ? "Питание"
                                      : page === "wallpapers" ? "Обои"
                                      : page === "clipboard" ? "Буфер обмена" : ""

    // launcher state
    property string query: ""
    property int sel: 0
    property string wifiSel: ""
    property bool showAuto: false
    readonly property string autoLabel: {
        const m = Wallpaper.autoMinutes;
        const h = Math.floor(m / 60), mm = m % 60;
        return h > 0 ? (h + "ч" + (mm > 0 ? " " + mm + "м" : "")) : (mm + "м");
    }
    function setAuto(frac) {
        Wallpaper.autoMinutes = Math.max(1, Math.min(1440, Math.round(1 + frac * 1439)));
        Wallpaper.saveState();
    }
    function submitWifi() {
        if (win.wifiSel === "") return;
        Sys.connectWifi(win.wifiSel, wifiPassInput.text);
        win.wifiSel = "";
        if (win.shell) win.shell.setPage("");
    }
    readonly property var apps: {
        const q = win.query.toLowerCase().trim();
        const out = [];
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            if (Apps.isHidden(a) && !Apps.showHidden) continue;
            const name = (a.name || "").toLowerCase();
            const comment = (a.comment || "").toLowerCase();
            const kwSrc = Array.isArray(a.keywords) ? a.keywords.join(" ") : (a.keywords || "");
            const kw = String(kwSrc).toLowerCase();
            if (q === "" || name.includes(q) || comment.includes(q) || kw.includes(q)) out.push(a);
        }
        out.sort((x, y) => {
            const px = Apps.isPinned(x), py = Apps.isPinned(y);
            if (px !== py) return px ? -1 : 1;
            return (x.name || "").localeCompare(y.name || "");
        });
        return out.slice(0, 60);
    }
    function launch(a) {
        if (!a) return;
        let cmd = a.command;
        if (typeof cmd === "string") cmd = ["sh", "-c", cmd];
        Quickshell.execDetached(cmd);
        if (win.shell) win.shell.closeOverlays();
    }
    onViewChanged: if (view === "launcher") { win.query = ""; win.sel = 0; }
    onPageChanged: {
        if (page === "wifi") { win.wifiSel = ""; Sys.refreshWifi(); }
        else if (page === "bluetooth") Sys.startBtScan();
    }

    // ── components ───────────────────────────────────────────────────
    component IconBtn: Text {
        property bool btnEnabled: true
        property string glyph: ""
        signal clicked()
        text: glyph
        font.family: Theme.font
        font.pixelSize: 14
        color: btnEnabled ? (btnMouse.containsMouse ? Theme.accent : Theme.subtext) : Theme.a(Theme.subtext, 0.35)
        Behavior on color { ColorAnimation { duration: 100 } }
        MouseArea {
            id: btnMouse
            anchors.fill: parent; anchors.margins: -6
            hoverEnabled: true; enabled: parent.btnEnabled
            onClicked: parent.clicked()
        }
    }

    component RoundBtn: Rectangle {
        id: rb
        property string glyph: ""
        property bool active: false
        property bool danger: false
        signal clicked()
        implicitWidth: 30; implicitHeight: 30; radius: 15
        color: active ? Theme.accent : (rbMouse.containsMouse ? Theme.surfaceHi : "transparent")
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            anchors.centerIn: parent
            font.family: Theme.font; font.pixelSize: 13
            color: rb.active ? Theme.bg : (rb.danger ? Theme.error : Theme.subtext)
            text: rb.glyph
        }
        MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: rb.clicked() }
    }

    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string label: ""
        property bool active: false
        signal tapped()
        Layout.fillWidth: true
        implicitHeight: 66
        radius: 16
        color: active ? Theme.a(Theme.accent, 0.22) : Theme.surface
        ColumnLayout {
            anchors.centerIn: parent; spacing: 4
            Text { Layout.alignment: Qt.AlignHCenter; font.family: Theme.font; font.pixelSize: 18; color: tile.active ? Theme.accent : Theme.subtext; text: tile.icon }
            Text { Layout.alignment: Qt.AlignHCenter; font.family: Theme.font; font.pixelSize: 10; color: tile.active ? Theme.text : Theme.subtext; text: tile.label }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: tile.tapped() }
    }

    component ClipRow: Rectangle {
        id: cr
        property var item: null
        property bool pinned: false
        implicitHeight: 46
        radius: 10
        color: crMouse.containsMouse ? Theme.surfaceHi : Theme.surface
        MouseArea {
            id: crMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: cr.pinned ? Clip.copyPin(cr.item) : Clip.copy(cr.item.id, cr.item.type)
        }
        RowLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 8
            Rectangle {
                visible: cr.item && cr.item.type === "image"
                Layout.preferredWidth: 44; Layout.preferredHeight: 30; radius: 6
                color: Theme.surfaceHi; clip: true
                Image {
                    anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                    source: (cr.item && cr.item.type === "image") ? ("file://" + cr.item.thumb) : ""
                }
            }
            Text {
                visible: !cr.item || cr.item.type !== "image"
                font.family: Theme.font; font.pixelSize: 14; color: Theme.accent; text: "\uf0f6"
            }
            Text {
                Layout.fillWidth: true
                font.family: Theme.font; font.pixelSize: 11; color: Theme.text
                elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                text: cr.item ? (cr.item.type === "image" ? "Изображение"
                      : (cr.item.text !== undefined && cr.item.text !== "" ? cr.item.text : cr.item.preview)) : ""
            }
            RoundBtn { glyph: "\uf08d"; active: cr.pinned; onClicked: cr.pinned ? Clip.unpin(cr.item.id) : Clip.pin(cr.item.id) }
            RoundBtn { glyph: "\uf1f8"; danger: true; visible: !cr.pinned; onClicked: Clip.del(cr.item.id) }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        signal clicked()
        implicitWidth: chipText.implicitWidth + 18
        implicitHeight: 26
        radius: 13
        color: chip.active ? Theme.a(Theme.accent, 0.25) : Theme.surface
        Text {
            id: chipText
            anchors.centerIn: parent
            font.family: Theme.font; font.pixelSize: 11
            color: chip.active ? Theme.accent : Theme.subtext
            text: chip.label
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
    }

    component TabBtn: Rectangle {
        id: tabBtn
        property string label: ""
        property bool active: false
        signal clicked()
        implicitWidth: tbText.implicitWidth + 22
        implicitHeight: 30
        radius: 15
        color: tabBtn.active ? Theme.accent : Theme.surface
        Text {
            id: tbText
            anchors.centerIn: parent
            font.family: Theme.font; font.pixelSize: 12
            color: tabBtn.active ? Theme.bg : Theme.subtext
            text: tabBtn.label
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: tabBtn.clicked() }
    }

    component ToggleRow: Rectangle {
        id: tr
        property string label: ""
        property string sub: ""
        property bool active: false
        signal toggled()
        implicitHeight: 52
        radius: 14
        color: Theme.surface
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 10
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { font.family: Theme.font; font.pixelSize: 14; color: Theme.text; text: tr.label }
                Text { font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext; text: tr.sub }
            }
            Rectangle {
                implicitWidth: 44; implicitHeight: 26; radius: 13
                color: tr.active ? Theme.accent : Theme.surfaceHi
                Rectangle {
                    width: 20; height: 20; radius: 10; color: Theme.bg
                    y: 3; x: tr.active ? 21 : 3
                    Behavior on x { NumberAnimation { duration: 140 } }
                }
                MouseArea { anchors.fill: parent; onClicked: tr.toggled() }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: dr
        property string devName: ""
        property bool selected: false
        signal clicked()
        implicitHeight: 40
        radius: 10
        color: selected ? Theme.a(Theme.accent, 0.18) : Theme.surface
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            Text { font.family: Theme.font; font.pixelSize: 13; color: dr.selected ? Theme.accent : Theme.text; text: dr.devName; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { visible: dr.selected; font.family: Theme.font; font.pixelSize: 12; color: Theme.accent; text: "\uf00c" }
        }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: dr.clicked() }
    }

    component PowerRow: Rectangle {
        id: pr
        property string icon: ""
        property string label: ""
        signal clicked()
        implicitHeight: 46
        radius: 12
        color: prMouse.containsMouse ? Theme.a(Theme.accent, 0.16) : Theme.surface
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
            Text { font.family: Theme.font; font.pixelSize: 15; color: Theme.accent; text: pr.icon }
            Text { font.family: Theme.font; font.pixelSize: 14; color: Theme.text; text: pr.label; Layout.fillWidth: true }
        }
        MouseArea { id: prMouse; anchors.fill: parent; hoverEnabled: true; onClicked: pr.clicked() }
    }

    component NotifItem: Rectangle {
        id: ni
        property var item: null
        property int itemIndex: 0
        implicitHeight: 48
        radius: 12
        color: Theme.surface
        RowLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 10
            Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.accent; text: "\uf0f3" }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { font.family: Theme.font; font.pixelSize: 12; color: Theme.text; text: (ni.item && ni.item.appName ? ni.item.appName + " · " : "") + (ni.item ? (ni.item.summary || "") : ""); elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: text !== ""; font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext; text: ni.item ? (ni.item.body || "") : ""; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            IconBtn { glyph: "\uf00d"; onClicked: Notif.dismissAt(ni.itemIndex) }
        }
    }

    component SliderRow: RowLayout {
        id: sl
        property string icon: ""
        property real value: 0
        signal moved(real v)
        signal committed(real v)
        signal iconClicked()
        spacing: 10
        Text {
            font.family: Theme.font; font.pixelSize: 15; color: Theme.accent; text: sl.icon
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: sl.iconClicked() }
        }
        Item {
            Layout.fillWidth: true; implicitHeight: 24
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: 3; color: Theme.surfaceHi
                Rectangle { width: parent.width * Math.max(0, Math.min(1, sl.value)); height: parent.height; radius: 3; color: Theme.accent }
            }
            MouseArea {
                anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6
                onPositionChanged: (m) => sl.moved(Math.max(0, Math.min(1, m.x / track.width)))
                onPressed: (m) => sl.moved(Math.max(0, Math.min(1, m.x / track.width)))
                onReleased: sl.committed(sl.value)
            }
        }
        Text {
            Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
            font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext
            text: Math.round(Math.max(0, Math.min(1, sl.value)) * 100) + "%"
        }
    }

    component MediaCard: Rectangle {
        id: mc
        implicitHeight: 68; radius: 16; color: Theme.surface
        RowLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 10
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 10; color: Theme.surfaceHi; clip: true
                Image {
                    anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                    source: win.artFile !== "" ? ("file://" + win.artFile) : win.artUrl
                    visible: (win.artFile !== "" || win.artUrl !== "")
                }
                Text {
                    anchors.centerIn: parent
                    visible: win.artFile === "" && win.artUrl === ""
                    font.family: Theme.font; font.pixelSize: 20; color: Theme.subtext; text: "\uf001"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.text; text: win.player ? win.player.trackTitle : ""; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: win.player ? win.player.trackArtist : ""; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            IconBtn { glyph: "\uf049"; btnEnabled: win.player && win.player.canGoPrevious; onClicked: win.player.previous() }
            IconBtn { glyph: win.mediaIcon(); onClicked: if (win.player) win.player.togglePlaying() }
            IconBtn { glyph: "\uf050"; btnEnabled: win.player && win.player.canGoNext; onClicked: win.player.next() }
        }
    }

    component WorkspacesRow: Row {
        id: wsRow
        property string output: ""
        spacing: 5
        Repeater {
            model: Umbriel.workspacesFor(output)
            delegate: Rectangle {
                required property var modelData
                width: modelData.active ? 14 : 6
                height: 6; radius: 3
                color: modelData.active ? Theme.accent
                     : modelData.occupied ? Theme.a(Theme.subtext, 0.75)
                     : Theme.a(Theme.subtext, 0.3)
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }
}
