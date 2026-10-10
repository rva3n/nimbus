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

    property string view: "idle"   // idle | panel | launcher | taskman
    property string panelPage: ""
    property string launcherTab: "apps"    // apps | clipboard | emoji (вкладки лончера)
    property int taskmanTab: 0             // вкладка диспетчера (0/1/2)
    property bool locked: false
    property string pamError: ""

    PamContext {
        id: pam
        user: Quickshell.env("USER") || "user"
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

    // Палитра читается самим Theme (FileView → ~/.cache/nimbus/colors.json).
    // Прогреваем синглтоны, чтобы они поднялись вместе с шеллом (они ленивые).
    Component.onCompleted: {
        void Theme.paletteLoaded;
        void Prefs.ready;
        void Weather.place;
        void SysStats.cpu;
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

    // Таймер завершился: алерт в островке + запись в историю (сигнал finished()
    // раньше никто не слушал — таймер истекал молча). DND не глушит: это будильник.
    Connections {
        target: Chrono
        function onFinished() {
            const snap = { appName: "Nimbus", summary: "Таймер завершён", body: "Время вышло" };
            Notif.add(snap);
            if (root.view === "idle" && !root.locked) Notif.toast(snap);
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
    Variants {
        model: Quickshell.screens
        delegate: MediaPill { modelData: modelData }
    }

    Lockscreen {
        locked: root.locked
        pam: pam
        errorText: root.pamError
    }

    // ── Actions ──────────────────────────────────────────────────────
    function openPanel()      { root.view = "panel"; root.panelPage = ""; }
    function openLauncher(tab) { root.launcherTab = tab || "apps"; root.view = "launcher"; }
    function togglePanel()    { if (root.view === "panel") { root.view = "idle"; root.panelPage = ""; } else { root.openPanel(); } }
    function toggleLauncher() { if (root.view === "launcher") { root.view = "idle"; } else { root.openLauncher(root.launcherTab); } }
    function taskman()        { if (root.view === "taskman") { root.view = "idle"; } else { root.view = "taskman"; root.panelPage = ""; } }
    function closeOverlays()  { root.view = "idle"; root.panelPage = ""; }
    function lock()           { root.view = "idle"; root.panelPage = ""; Quickshell.execDetached(["umbriel", "msg", "dpms-on"]); root.locked = true; }
    function setPage(p)       { root.panelPage = p; }
    // совместимость с чипами острова: weather — страница, system — диспетчер
    function setTab(t) {
        if (t === "weather")
            root.togglePage("weather");
        else if (t === "system")
            root.taskman();
        else
            root.openPanel();
    }
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
        function launcher() { if (root.view === "launcher") { root.closeOverlays(); } else { root.openLauncher("apps"); } }
        function panel() { root.togglePanel() }
        function quicksettings() { root.togglePanel() }
        function page(name: string) { root.view = "panel"; root.panelPage = name; }
        function pageRoot() { root.view = "panel"; root.panelPage = ""; }
        function pageWifi() { root.view = "panel"; root.panelPage = "wifi"; }
        function pageBluetooth() { root.view = "panel"; root.panelPage = "bluetooth"; }
        function pageVolume() { root.view = "panel"; root.panelPage = "volume"; }
        function pageBrightness() { root.view = "panel"; root.panelPage = "brightness"; }
        function pagePower() { root.view = "panel"; root.panelPage = "power"; }
        function pageWeather() { root.view = "panel"; root.panelPage = "weather"; }
        function pageSystem() { root.view = "taskman"; root.panelPage = ""; }
        function taskman() { root.view = "taskman"; root.panelPage = ""; }
        function taskmanAt(i: int) { root.taskmanTab = i; root.view = "taskman"; root.panelPage = ""; }
        function tab(name: string) { root.setTab(name); }
        function pageCalendar() { root.view = "panel"; root.panelPage = "calendar"; }
        function pageTimers() { root.view = "panel"; root.panelPage = "timers"; }
        function emoji() {
            if (root.view === "launcher" && root.launcherTab === "emoji")
                root.closeOverlays();
            else
                root.openLauncher("emoji");
        }
        function pageSettings() { root.view = "panel"; root.panelPage = "settings"; }
        function weatherRefresh() { Weather.refresh(); }
        function wallpapers() { root.togglePage("wallpapers"); }
        function clipboard() {
            if (root.view === "launcher" && root.launcherTab === "clipboard") {
                root.closeOverlays();
            } else {
                root.launcherTab = "clipboard";
                root.view = "launcher";
                Clip.refresh();
            }
        }
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
