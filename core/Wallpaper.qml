pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper manager: local files + Wallhaven search; applies via awww (image/gif)
// or mpvpaper (video). Persists the current choice.
Singleton {
    id: w

    property string tab: "photos"         // photos | videos | wallhaven
    property var localItems: []
    property var results: []
    property bool loading: false

    readonly property var photos: localItems.filter(i => !i.video)
    readonly property var videos: localItems.filter(i => i.video)

    // Wallhaven filters
    property string query: ""
    property string sorting: "toplist"    // toplist | date_added | random | views | favorites | relevance
    property string category: "general"   // general | anime | people | all
    property string purity: "sfw"         // sfw | sketchy
    property string minRes: "1920x1080"
    property int page: 1

    property string currentPath: ""
    property bool currentIsVideo: false
    property bool autoEnabled: false
    property int autoMinutes: 30

    // random online wallpaper (for auto-change)
    Process {
        id: autoWhProc
        command: ["sh", "-c", "curl -s --max-time 20 'https://wallhaven.cc/api/v1/search?sorting=random&categories=100&purity=100&atleast=1920x1080' | jq -r '.data[0].path'"]
        stdout: SplitParser {
            onRead: line => {
                const s = line.trim();
                if (s.indexOf("http") === 0) w.applyUrl({ id: "auto-" + Date.now(), full: s, type: "image/jpeg" });
            }
        }
    }
    Timer {
        interval: w.autoMinutes * 60000
        running: w.autoEnabled
        repeat: true
        onTriggered: w.nextRandom()
    }
    function nextRandom() {
        if (w.photos.length > 0) {
            const it = w.photos[Math.floor(Math.random() * w.photos.length)];
            w.apply(it.path, false);
        } else {
            autoWhProc.running = false; autoWhProc.running = true;
        }
    }

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    // ── local scan ─────────────────────────────────────────────────────
    Process {
        id: localProc
        command: ["sh", "-c",
            "find \"$HOME/Pictures\" \"$HOME/Изображения\" \"$HOME/Загрузки\" -maxdepth 3 -type f " +
            "-not -path '*/Screenshots/*' -not -path '*/screenshots/*' " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' " +
            "-o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) 2>/dev/null | sort | head -300"]
        stdout: SplitParser {
            onRead: line => {
                if (line.length === 0) return;
                const low = line.toLowerCase();
                const video = /\.(mp4|webm|mkv|mov)$/.test(low);
                const arr = w.localItems.slice();
                arr.push({ path: line, video: video, name: line.split("/").pop() });
                w.localItems = arr;
            }
        }
        onExited: w.loading = false
    }
    function refreshLocal() { w.localItems = []; w.loading = true; localProc.running = false; localProc.running = true; }

    // ── Wallhaven ──────────────────────────────────────────────────────
    Process {
        id: whProc
        stdout: SplitParser { onRead: line => w.parseWallhaven(line) }
        onExited: w.loading = false
    }
    function buildUrl() {
        const cat = w.category === "all" ? "111" : w.category === "anime" ? "010" : w.category === "people" ? "001" : "100";
        const pur = w.purity === "sketchy" ? "001" : "100";
        let url = "https://wallhaven.cc/api/v1/search?sorting=" + w.sorting
                + "&categories=" + cat + "&purity=" + pur
                + "&atleast=" + w.minRes + "&page=" + w.page;
        if (w.query.length > 0) url += "&q=" + encodeURIComponent(w.query);
        return url;
    }
    function search() {
        w.results = []; w.page = 1; w.loading = true;
        whProc.command = ["curl", "-s", "--max-time", "25", w.buildUrl()];
        whProc.running = false; whProc.running = true;
    }
    function nextPage() {
        w.page += 1; w.loading = true;
        whProc.command = ["curl", "-s", "--max-time", "25", w.buildUrl()];
        whProc.running = false; whProc.running = true;
    }
    function parseWallhaven(text) {
        try {
            const j = JSON.parse(text);
            if (!j.data) return;
            const arr = w.results.slice();
            for (const it of j.data) {
                arr.push({
                    id: it.id,
                    thumb: it.thumbs && it.thumbs.small ? it.thumbs.small : it.path,
                    full: it.path,
                    resolution: it.resolution,
                    type: it.file_type
                });
            }
            w.results = arr;
        } catch (e) { console.log("wallhaven parse:", e); }
    }

    // ── MotionBGs (online video wallpapers) ────────────────────────────
    property var motionResults: []
    property string motionQuery: ""
    property int motionSourceIndex: 0
    readonly property var motionSources: [
        "https://motionbgs.com/",
        "https://motionbgs.com/4k/",
        "https://motionbgs.com/gifs/",
        "https://motionbgs.com/mobile/",
        "https://motionbgs.com/2/"
    ]
    Process {
        id: motionProc
        stdout: SplitParser { onRead: line => w.parseMotion(line) }
        onExited: w.loading = false
    }
    function fetchMotion(url) {
        motionProc.command = ["sh", "-c",
            "curl -s --max-time 25 '" + url + "' | grep -oE '/media/[0-9]+/[A-Za-z0-9._-]+' | sort -u | head -200"];
        motionProc.running = false; motionProc.running = true;
    }
    function searchMotion() {
        w.motionResults = []; w.loading = true; w.motionSourceIndex = 0;
        if (w.motionQuery && w.motionQuery.length > 0)
            fetchMotion("https://motionbgs.com/search?query=" + encodeURIComponent(w.motionQuery));
        else
            fetchMotion(w.motionSources[0]);
    }
    function loadMoreMotion() {
        if (w.loading) return;
        if (w.motionSourceIndex >= w.motionSources.length - 1) return;
        w.motionSourceIndex += 1;
        w.loading = true;
        fetchMotion(w.motionSources[w.motionSourceIndex]);
    }
    function parseMotion(path) {
        const m = path.match(/^\/media\/([0-9]+)\/(.+)$/);
        if (!m) return;
        const id = m[1];
        let slug = m[2];
        const dot = slug.lastIndexOf(".");
        if (dot > 0) slug = slug.slice(0, dot);
        slug = slug.replace(/\.\d+x\d+$/, "");
        const arr = w.motionResults.slice();
        for (const it of arr) if (it.id === id) return;
        arr.push({
            id: id,
            thumb: "https://motionbgs.com" + path,
            video: "https://motionbgs.com/media/" + id + "/" + slug + ".1920x1080.mp4"
        });
        w.motionResults = arr;
    }

    // ── apply ──────────────────────────────────────────────────────────
    Process {
        id: dlProc
        property string url: ""
        property string dest: ""
        command: ["curl", "-sL", "--max-time", "120", "-o", dlProc.dest, dlProc.url]
        onExited: (code) => { if (code === 0) w.apply(dlProc.dest, false); }
    }
    function applyUrl(item) {
        const ext = (item.type && item.type.indexOf("png") !== -1) ? "png" : "jpg";
        const dir = Quickshell.cacheDir + "/wallpapers";
        Quickshell.execDetached(["mkdir", "-p", dir]);
        dlProc.dest = dir + "/" + item.id + "." + ext;
        dlProc.url = item.full;
        dlProc.running = false; dlProc.running = true;
    }

    function apply(path, isVideo) {
        w.currentPath = path;
        w.currentIsVideo = isVideo;
        if (isVideo) {
            Quickshell.execDetached(["sh", "-c",
                "pkill -9 -x mpvpaper 2>/dev/null; pkill -9 -x awww-daemon 2>/dev/null; sleep 0.2; " +
                "setsid mpvpaper -f -o 'no-audio loop' '*' " + shq(path) + " >/dev/null 2>&1"]);
        } else {
            Quickshell.execDetached(["sh", "-c",
                "pkill -9 -x mpvpaper 2>/dev/null; " +
                "pgrep -x awww-daemon >/dev/null || { setsid awww-daemon >/dev/null 2>&1 & sleep 0.6; }; " +
                "awww img " + shq(path) + " --transition-type any --transition-duration 1 >/dev/null 2>&1"]);
        }
        runMatugen(path, isVideo);
        saveState();
    }

    function applyVideoUrl(url) {
        w.currentPath = url;
        w.currentIsVideo = true;
        Quickshell.execDetached(["sh", "-c",
            "pkill -9 -x mpvpaper 2>/dev/null; pkill -9 -x awww-daemon 2>/dev/null; sleep 0.2; " +
            "setsid mpvpaper -f -o 'no-audio loop' '*' " + shq(url) + " >/dev/null 2>&1"]);
        Quickshell.execDetached(["sh", "-c",
            "ffmpeg -y -ss 3 -i " + shq(url) + " -frames:v 1 -vf scale=640:-1 /tmp/nimbus-frame.png >/dev/null 2>&1; " +
            "matugen --prefer saturation image /tmp/nimbus-frame.png >/dev/null 2>&1"]);
        saveState();
    }

    // Recolour the system + shell from the wallpaper via matugen.
    function runMatugen(path, isVideo) {
        if (isVideo) {
            Quickshell.execDetached(["sh", "-c",
                "ffmpeg -y -ss 3 -i " + shq(path) + " -frames:v 1 -vf scale=640:-1 /tmp/nimbus-frame.png >/dev/null 2>&1; " +
                "matugen --prefer saturation image /tmp/nimbus-frame.png >/dev/null 2>&1"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "matugen --prefer saturation image " + shq(path) + " >/dev/null 2>&1"]);
        }
    }

    function saveState() {
        const json = JSON.stringify({ path: w.currentPath, video: w.currentIsVideo, auto: w.autoEnabled, autoMin: w.autoMinutes });
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + shq(Quickshell.stateDir) + "; printf %s " + shq(json) + " > " + shq(Quickshell.stateDir + "/wallpaper.json")]);
    }

    Process {
        id: restoreProc
        command: ["sh", "-c", "cat " + shq(Quickshell.stateDir + "/wallpaper.json") + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    if (typeof j.auto === "boolean") w.autoEnabled = j.auto;
                    if (j.autoMin) w.autoMinutes = j.autoMin;
                    if (j.path) w.apply(j.path, j.video);
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        refreshLocal();
        restoreProc.running = true;
    }
}
