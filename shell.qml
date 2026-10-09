import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.Pam
import "core"
import "components"

ShellRoot {
    id: root

    property string view: "idle"   // idle | panel | launcher
    property string panelPage: ""
    property bool locked: false
    property string pamError: ""

    PamContext {
        id: pam
        user: "tony"
        config: "login"
        onCompleted: (result) => {
            if (result === PamResult.Success) { root.pamError = ""; root.locked = false; }
            else root.pamError = "Неверный пароль";
        }
        onError: (error) => { root.pamError = "Ошибка аутентификации"; }
    }

    onLockedChanged: {
        if (root.locked) { root.pamError = ""; pam.start(); }
        else { try { pam.abort(); } catch (e) {} }
    }

    // Bind PipeWire nodes so volume/mute changes are reactive in the UI.
    PwObjectTracker {
        objects: {
            const a = [];
            for (const n of Pipewire.nodes.values) a.push(n);
            return a;
        }
    }

    // Wallpaper-derived color scheme (written by matugen).
    Process {
        id: colorsProc
        command: ["cat", Quickshell.env("HOME") + "/.cache/nimbus/colors.json"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const s = line.trim();
                if (s.length > 1) { try { Theme.applyScheme(JSON.parse(s)); } catch (e) {} }
            }
        }
    }
    Timer {
        interval: 2500; running: true; repeat: true
        onTriggered: { colorsProc.running = false; colorsProc.running = true; }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        onNotification: (n) => {
            const snap = { appName: n.appName, summary: n.summary, body: n.body, appIcon: n.appIcon, raw: n };
            Notif.add(snap);
            if (!Notif.dnd && root.view === "idle" && !root.locked) Notif.toast(snap);
        }
    }

    // Backdrop first → below the island (Overlay layer).
    Variants {
        model: Quickshell.screens
        delegate: Backdrop { shell: root; active: root.view !== "idle" }
    }
    Variants {
        model: Quickshell.screens
        delegate: Island { shell: root; view: root.view }
    }

    Lockscreen {
        locked: root.locked
        pam: pam
        errorText: root.pamError
    }

    // ── Actions ──────────────────────────────────────────────────────
    function togglePanel()    { if (root.view === "panel") { root.view = "idle"; root.panelPage = ""; } else { root.view = "panel"; root.panelPage = ""; } }
    function toggleLauncher() { if (root.view === "launcher") { root.view = "idle"; } else { root.view = "launcher"; } }
    function closeOverlays()  { root.view = "idle"; root.panelPage = ""; }
    function lock()           { root.view = "idle"; root.panelPage = ""; Quickshell.execDetached(["umbriel", "msg", "dpms-on"]); root.locked = true; }
    function setPage(p)       { root.panelPage = p; }
    function togglePage(p) {
        if (root.view === "panel" && root.panelPage === p) { root.view = "idle"; root.panelPage = ""; }
        else { root.view = "panel"; root.panelPage = p; }
    }

    function volumeStep(d) {
        const s = Pipewire.defaultAudioSink;
        if (!s) return;
        const nv = Math.max(0, Math.min(1, s.audio.volume + d));
        s.audio.volume = nv;
        if (root.view === "idle") Osd.show("volume", nv, s.audio.muted);
    }
    function volumeMute() {
        const s = Pipewire.defaultAudioSink;
        if (!s) return;
        s.audio.muted = !s.audio.muted;
        if (root.view === "idle") Osd.show("volume", s.audio.volume, s.audio.muted);
    }
    function brightnessStep(d) {
        const nv = Math.max(0, Math.min(1, Sys.brightnessFraction + d));
        Sys.setBrightnessPct(nv * 100);
        if (root.view === "idle") Osd.show("brightness", nv, false);
    }

    // ── IPC (compositor keybinds) ────────────────────────────────────
    IpcHandler {
        target: "nimbus"
        function launcher() { root.toggleLauncher() }
        function panel() { root.togglePanel() }
        function quicksettings() { root.togglePanel() }
        function page(name: string) { root.view = "panel"; root.panelPage = name; }
        function pageRoot() { root.view = "panel"; root.panelPage = ""; }
        function pageWifi() { root.view = "panel"; root.panelPage = "wifi"; }
        function pageBluetooth() { root.view = "panel"; root.panelPage = "bluetooth"; }
        function pageVolume() { root.view = "panel"; root.panelPage = "volume"; }
        function pageBrightness() { root.view = "panel"; root.panelPage = "brightness"; }
        function pagePower() { root.view = "panel"; root.panelPage = "power"; }
        function wallpapers() { root.togglePage("wallpapers"); }
        function clipboard() { root.togglePage("clipboard"); Clip.refresh(); }
        function screenshotRegion() {
            Quickshell.execDetached(["sh", "-c",
                "mkdir -p \"$HOME/Pictures/Screenshots\"; f=\"$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png\"; " +
                "if grim -g \"$(slurp)\" \"$f\" 2>/dev/null; then wl-copy < \"$f\"; notify-send -a Nimbus 'Скриншот' 'Область сохранена и скопирована'; fi"]);
        }
        function screenshotFull() {
            Quickshell.execDetached(["sh", "-c",
                "mkdir -p \"$HOME/Pictures/Screenshots\"; f=\"$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png\"; " +
                "if grim \"$f\" 2>/dev/null; then wl-copy < \"$f\"; notify-send -a Nimbus 'Скриншот' 'Весь экран сохранён и скопирован'; fi"]);
        }
        function wpLocal() { root.view = "panel"; root.panelPage = "wallpapers"; Wallpaper.tab = "photos"; Wallpaper.refreshLocal(); }
        function wpVideos() { root.view = "panel"; root.panelPage = "wallpapers"; Wallpaper.tab = "videos"; Wallpaper.refreshLocal(); }
        function wpWallhaven() { root.view = "panel"; root.panelPage = "wallpapers"; Wallpaper.tab = "wallhaven"; Wallpaper.search(); }
        function wpMotion() { root.togglePage("wallpapers"); Wallpaper.tab = "motion"; Wallpaper.motionQuery = ""; Wallpaper.searchMotion(); }
        function wpMotionMore() { Wallpaper.loadMoreMotion(); }
        function wpApplyFirst() { if (Wallpaper.results.length > 0) Wallpaper.applyUrl(Wallpaper.results[0]); }
        function wpApplyVideo() { if (Wallpaper.videos.length > 0) Wallpaper.apply(Wallpaper.videos[0].path, true); }
        function wpApplyMotion() { if (Wallpaper.motionResults.length > 0) Wallpaper.applyVideoUrl(Wallpaper.motionResults[0].video); }
        function lock() { root.lock() }
        function volumeUp() { root.volumeStep(0.05) }
        function volumeDown() { root.volumeStep(-0.05) }
        function volumeMute() { root.volumeMute() }
        function brightnessUp() { root.brightnessStep(0.05) }
        function brightnessDown() { root.brightnessStep(-0.05) }
    }
}
