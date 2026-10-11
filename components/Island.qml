import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import "../core"
import "../ui"
import "panel"
import "taskman"

// Nimbus island. The Wayland surface is a fixed-size transparent band; the pill
// inside it is animated in QML (smooth). Input is limited to the pill via mask.
PanelWindow {
    id: win
    required property var modelData
    property var shell: null
    property string view: "idle"        // idle | panel | launcher | taskman | tray

    screen: modelData
    color: "transparent"
    anchors { top: true; left: true; right: true }
    // Полоска под остров зарезервирована ровно по капсулу (6 + 34), чтобы
    // максимизированные окна не заезжали под неё; отступ снизу даёт само окно.
    // В fullscreen остров скрывается и зона не держится.
    exclusiveZone: win.fullscreenActive ? 0 : Theme.topReserve
    implicitHeight: Math.max(664, win.panelMax + Theme.dp(16))
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nimbus-island"
    WlrLayershell.keyboardFocus: (view === "launcher" || view === "panel" || view === "taskman" || view === "tray")
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: pill; radius: pill.radius }

    readonly property string mode: (Notif.visible && view === "idle") ? "notif"
                                 : (Osd.visible && view === "idle") ? "osd" : view
    readonly property bool big: mode === "panel" || mode === "launcher" || mode === "taskman" || mode === "tray"
    readonly property string page: win.shell ? win.shell.panelPage : ""
    // ширина панели: лончер 560, настройки 620, диспетчер 920, трей 360, остальное 404
    readonly property int panelW: win.mode === "launcher" ? 560
        : (win.page === "settings" ? 620
        : (win.mode === "taskman" ? 920
        : (win.mode === "tray" ? 360 : 404)))
    // активное окно во весь экран на этом output → остров уступает игрушке
    readonly property bool fullscreenActive: win.screen
        ? Umbriel.fullscreenFor(win.screen.name, win.screen.width, win.screen.height) : false
    // панель по запросу, OSD и тосты показываются всегда; idle прячется в fullscreen
    visible: win.big || Osd.visible || Notif.visible || !win.fullscreenActive
    // Максимальная высота панели: 75% экрана, чтобы высокие страницы (обои,
    // звук) помещались целиком, а не обрезались прежними жёсткими 652px.
    readonly property real panelMax: Math.max(360, Math.round((win.screen ? win.screen.height : 1080) * 0.75))

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

    // Настоящая тень: обёртка с запасом, layer.effect рисует капсулу
    // с гауссовой тенью (в Umbriel теней слоёв нет — делаем сами).
    Item {
        id: shadowHost
        readonly property int padH: Theme.dp(30)
        readonly property int padTop: Theme.dp(10)
        readonly property int padBottom: Theme.dp(24)

        x: Math.round((parent.width - width) / 2)
        y: Theme.dp(6) - padTop
        width: pill.width + padH * 2
        height: pill.height + padTop + padBottom
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            // альфа тени ниже порога blur_ignore_alpha (0.72), чтобы композитор
            // не размывал фон под тенью — только под самой капсулой
            shadowColor: Theme.a(Theme.scrim, 0.68)
            shadowBlur: 0.9
            shadowVerticalOffset: Theme.dp(7)
            shadowOpacity: 1
        }

        Rectangle {
            id: pill
            x: shadowHost.padH
            y: shadowHost.padTop
            width: win.big ? Theme.dp(win.panelW) : (idlePill.implicitWidth + Theme.pad * 2)
        height: win.big ? Math.min(contentCol.implicitHeight + Theme.dp(32), win.panelMax) : Math.max(Theme.height, idlePill.implicitHeight + Theme.dp(6))
        radius: win.big ? Theme.radiusXl : height / 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.a(Theme.outline, 0.25)
        clip: true
        Behavior on width { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveDefaultSpatial } }
        Behavior on height { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveDefaultSpatial } }
        Behavior on radius { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveDefaultSpatial } }

        // ── IDLE / OSD / NOTIF ───────────────────────────────────────
        IdlePill {
            id: idlePill
            visible: !win.big
            anchors.centerIn: parent
            mode: win.mode
            now: win.now
            output: win.screen.name
            shell: win.shell
        }

        // ── PANEL ────────────────────────────────────────────────────
        Flickable {
            id: panelView
            visible: win.big
            width: Theme.dp(win.panelW) - Theme.dp(32)
            height: Math.min(contentCol.implicitHeight, win.panelMax - Theme.dp(32))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.dp(16)
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: contentCol
                width: panelView.width
                spacing: Theme.dp(14)

                // header
                RowLayout {
                    Layout.fillWidth: true
                    IconButton {
                        icon: "arrow_back"
                        visible: win.mode === "panel" && win.page !== ""
                        onClicked: if (win.shell) win.shell.setPage("")
                    }
                    ColumnLayout {
                        spacing: 0
                        visible: win.mode === "panel" && win.page === ""
                        Text {
                            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("headlineSmall")
                            font.weight: Theme.typeWeight("headlineSmall"); color: Theme.text
                            text: Qt.formatDateTime(win.now, "HH:mm")
                        }
                        Text {
                            font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                            color: Theme.subtext
                            text: win.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
                        }
                    }
                    Text {
                        visible: win.mode === "panel" && win.page !== ""
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("titleLarge")
                        font.weight: Theme.typeWeight("titleLarge"); color: Theme.text
                        text: win.pageTitle
                    }
                    Text { // заголовок вида «трей»
                        visible: win.mode === "tray"
                        font.family: Theme.textFont; font.pixelSize: Theme.typeSize("titleLarge")
                        font.weight: Theme.typeWeight("titleLarge"); color: Theme.text
                        text: "Трей"
                    }
                    Item { Layout.fillWidth: true }
                    IconButton {
                        visible: win.mode === "panel" && win.page === ""
                        icon: "settings"
                        onClicked: if (win.shell) win.shell.setPage(win.page === "settings" ? "" : "settings")
                    }
                    IconButton {
                        visible: win.mode === "panel"
                        icon: "power_settings_new"
                        onClicked: if (win.shell) win.shell.setPage(win.page === "power" ? "" : "power")
                    }
                }

                RootPage { win: win }
                WifiPage { win: win }
                BtPage { win: win }
                VolumePage { win: win }
                BrightnessPage { win: win }
                WallpapersPage { win: win }
                PowerPage { win: win }
                WeatherPage { win: win }
                CalendarPage { win: win }
                TimersPage { win: win }
                SettingsPage { win: win }

                TaskManager { visible: win.mode === "taskman"; shell: win.shell; initialTab: win.shell ? win.shell.taskmanTab : 0 }

                // Трей — вид острова: список живёт в той же капсуле под шапкой,
                // как страницы панели. qmldir не объявляет TrayList, поэтому
                // грузим по source (как TrayRow в IdlePill).
                Loader {
                    id: trayPage
                    active: win.mode === "tray"
                    source: "TrayList.qml"
                    Layout.fillWidth: true
                    Binding { target: trayPage.item; property: "shell"; value: win.shell; when: trayPage.item !== null }
                    Binding { target: trayPage.item; property: "win"; value: win; when: trayPage.item !== null }
                }

                Launcher { active: win.mode === "launcher"; shell: win.shell; tab: win.shell ? win.shell.launcherTab : "apps" }
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
                                      : page === "clipboard" ? "Буфер обмена"
                                      : page === "weather" ? "Погода"
                                      : page === "system" ? "Система"
                                      : page === "calendar" ? "Календарь"
                                      : page === "timers" ? "Таймеры"
                                      : page === "emoji" ? "Эмодзи"
                                      : page === "settings" ? "Настройки" : ""

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
    function submitWifi(pass) {
        if (win.wifiSel === "") return;
        Sys.connectWifi(win.wifiSel, pass || "");
        win.wifiSel = "";
        if (win.shell) win.shell.setPage("");
    }
    onPageChanged: {
        if (page === "wifi") { win.wifiSel = ""; Sys.refreshWifi(); }
        else if (page === "bluetooth") Sys.startBtScan();
    }
}
