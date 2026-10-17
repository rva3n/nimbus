pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper manager: multi-source online (Wallhaven, MotionBGs) + local photos/videos.
// Downloads online wallpapers into ~/.cache/oberon/wallpapers before applying via
// oberonwall (images) or mpvpaper (videos), and triggers matugen theme generation.
Singleton {
    id: w

    // ── Source tabs ────────────────────────────────────────────────────
    // "wallhaven" | "motion" | "photos" | "videos"
    property string tab: "wallhaven"

    // ── Local items ────────────────────────────────────────────────────
    property var localItems: []
    property var _localBuf: []
    readonly property var photos: localItems.filter(i => !i.video)
    readonly property var videos: localItems.filter(i => i.video)

    // ── Busy / status flags ────────────────────────────────────────────
    property bool localBusy: false
    property bool whBusy: false
    property bool motionBusy: false
    property bool applying: false
    readonly property bool loading: localBusy || whBusy || motionBusy || applying

    // ── Current wallpaper & auto-rotation state ────────────────────────
    property string currentPath: ""
    property bool currentIsVideo: false
    property bool autoEnabled: false
    property int autoMinutes: 30

    // ── Wallhaven state & filters ──────────────────────────────────────
    property var results: []
    property alias whResults: w.results

    property int whPage: 1
    property int whLastPage: 1
    property int whTotal: 0

    property string whQuery: ""
    property string whCategories: "111"       // bit 0: General, bit 1: Anime, bit 2: People
    property string whSorting: "toplist"      // toplist | hot | date_added | views | favorites | random
    property string whTopRange: "1M"          // 1d | 3d | 1w | 1M | 3M | 6M | 1y
    property string whPurity: "100"           // 100 (SFW) | 110 (SFW+Sketchy)
    property string whAtleast: ""             // "" | "1920x1080" | "2560x1440" | "3840x2160"
    property string whRatios: "16x9,16x10"    // "" | "16x9,16x10" | "21x9" | "16x9"
    property string whColor: ""               // "" or hex without # from Wallhaven palette

    readonly property var whPalette: [
        "660000", "cc0000", "ea4c88", "993399", "663399",
        "333399", "0066cc", "0099cc", "66cccc", "77cc33",
        "336600", "cccc33", "ffcc33", "ff9900", "ff6600",
        "cc6633", "996633", "000000", "424153", "999999"
    ]

    // Legacy aliases for compatibility with IPC / callers
    property alias query: w.whQuery
    property alias sorting: w.whSorting
    property alias minRes: w.whAtleast
    property alias page: w.whPage

    // ── MotionBGs state & filters ──────────────────────────────────────
    property var motionResults: []
    property var _motionBuf: []
    property string motionCategory: ""        // "" | anime | games | cyberpunk | nature | space | car | fantasy | dark
    property string motionQuery: ""
    property int motionPage: 1
    property bool motionHasMore: true

    readonly property string matugenConf: Quickshell.env("HOME") + "/oberon/matugen/config.toml"

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    // ── Auto-rotation timer ────────────────────────────────────────────
    Process {
        id: autoWhProc
        command: ["sh", "-c", "curl -fsSL --max-time 20 'https://wallhaven.cc/api/v1/search?sorting=random&categories=111&purity=100&atleast=1920x1080' | jq -r '.data[0].path // empty'"]
        stdout: SplitParser {
            onRead: line => {
                const s = line.trim();
                if (s.indexOf("http") === 0)
                    w.applyWallhaven({ id: "auto-" + Date.now(), path: s, full: s, type: "image/jpeg" });
            }
        }
    }

    Timer {
        interval: Math.max(1, w.autoMinutes) * 60000
        running: w.autoEnabled
        repeat: true
        onTriggered: w.nextRandom()
    }

    function nextRandom() {
        if (w.tab === "videos" && w.videos.length > 0) {
            const it = w.videos[Math.floor(Math.random() * w.videos.length)];
            w.apply(it.path, true);
        } else if (w.photos.length > 0) {
            const it = w.photos[Math.floor(Math.random() * w.photos.length)];
            w.apply(it.path, false);
        } else {
            autoWhProc.running = false;
            autoWhProc.running = true;
        }
    }

    // ── Local scan (buffered SplitParser) ──────────────────────────────
    Process {
        id: localProc
        command: ["sh", "-c",
            "pic_xdg=$(xdg-user-dir PICTURES 2>/dev/null || true); " +
            "for d in \"$pic_xdg\" \"$HOME/Pictures\" \"$HOME/Изображения\" \"$HOME/Downloads\" \"$HOME/Загрузки\" \"$HOME/.local/share/wallpapers\"; do " +
            "  [ -n \"$d\" ] && [ -d \"$d\" ] && find \"$d\" -maxdepth 3 -type f " +
            "    -not -path '*/Screenshots/*' -not -path '*/screenshots/*' -not -name '*.part' " +
            "    \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' " +
            "    -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) 2>/dev/null; " +
            "done; " +
            "if [ -d \"$HOME/.cache/oberon/wallpapers\" ]; then " +
            "  find \"$HOME/.cache/oberon/wallpapers\" -maxdepth 2 -type f -not -name '*.part' " +
            "    \\( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.gif' " +
            "    -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null; " +
            "fi | awk '!seen[$0]++' | head -500"
        ]
        stdout: SplitParser {
            onRead: line => {
                const s = line.trim();
                if (s.length === 0) return;
                const low = s.toLowerCase();
                const video = /\.(mp4|webm|mkv|mov|gif)$/.test(low);
                w._localBuf.push({
                    path: s,
                    video: video,
                    name: s.split("/").pop(),
                    resolution: video ? "LIVE" : ""
                });
            }
        }
        onExited: {
            w.localItems = w._localBuf;
            w._localBuf = [];
            w.localBusy = false;
        }
    }

    function refreshLocal() {
        w._localBuf = [];
        w.localBusy = true;
        localProc.running = false;
        localProc.running = true;
    }

    // ── Wallhaven API ──────────────────────────────────────────────────
    Process {
        id: whProc
        stdout: SplitParser {
            onRead: line => w.parseWallhaven(line)
        }
        onExited: w.whBusy = false
    }

    function toggleWhCategory(bitIndex) {
        if (bitIndex < 0 || bitIndex > 2) return;
        let bits = (w.whCategories && w.whCategories.length === 3) ? w.whCategories.split("") : ["1", "1", "1"];
        bits[bitIndex] = bits[bitIndex] === "1" ? "0" : "1";
        if (bits.join("") === "000")
            bits[bitIndex] = "1";
        w.whCategories = bits.join("");
        w.searchWallhaven();
    }

    function buildUrl() {
        const cats = (w.whCategories && w.whCategories.length === 3) ? w.whCategories : "111";
        const pur = (w.whPurity && w.whPurity.length === 3) ? w.whPurity : "100";
        let url = "https://wallhaven.cc/api/v1/search?sorting=" + encodeURIComponent(w.whSorting)
                + "&categories=" + encodeURIComponent(cats)
                + "&purity=" + encodeURIComponent(pur)
                + "&page=" + Math.max(1, w.whPage);
        if (w.whSorting === "toplist" && w.whTopRange.length > 0)
            url += "&topRange=" + encodeURIComponent(w.whTopRange);
        if (w.whAtleast.length > 0)
            url += "&atleast=" + encodeURIComponent(w.whAtleast);
        if (w.whRatios.length > 0)
            url += "&ratios=" + encodeURIComponent(w.whRatios);
        if (w.whColor.length > 0)
            url += "&colors=" + encodeURIComponent(w.whColor);
        if (w.whQuery.trim().length > 0)
            url += "&q=" + encodeURIComponent(w.whQuery.trim());
        return url;
    }

    function _fetchWallhaven() {
        w.whBusy = true;
        const url = w.buildUrl();
        whProc.command = ["sh", "-c", "curl -fsSL --max-time 25 " + shq(url) + "; printf '\\n'"];
        whProc.running = false;
        whProc.running = true;
    }

    function searchWallhaven(q) {
        if (q !== undefined)
            w.whQuery = String(q);
        w.whPage = 1;
        w._fetchWallhaven();
    }

    function search() {
        w.searchWallhaven(w.whQuery);
    }

    function whGoPage(p) {
        const maxP = Math.max(1, w.whLastPage);
        const target = Math.max(1, Math.min(maxP, Math.round(p)));
        w.whPage = target;
        w._fetchWallhaven();
    }

    function whNextPage() {
        if (w.whPage < w.whLastPage)
            w.whGoPage(w.whPage + 1);
    }

    function whPrevPage() {
        if (w.whPage > 1)
            w.whGoPage(w.whPage - 1);
    }

    function nextPage() {
        w.whNextPage();
    }

    function parseWallhaven(text) {
        const trimmed = text.trim();
        if (trimmed.length === 0) return;
        try {
            const j = JSON.parse(trimmed);
            if (j.meta) {
                w.whPage = Number(j.meta.current_page) || w.whPage;
                w.whLastPage = Math.max(1, Number(j.meta.last_page) || 1);
                w.whTotal = Number(j.meta.total) || 0;
            }
            if (!j.data) return;
            const arr = [];
            for (const it of j.data) {
                arr.push({
                    id: it.id,
                    thumb: (it.thumbs && (it.thumbs.small || it.thumbs.original)) ? (it.thumbs.small || it.thumbs.original) : it.path,
                    path: it.path,
                    full: it.path,
                    resolution: it.resolution || "",
                    type: it.file_type || "image/jpeg",
                    colors: it.colors || []
                });
            }
            w.results = arr;
        } catch (e) {
            console.log("wallhaven parse:", e);
        }
    }

    // ── MotionBGs (online live video wallpapers) ───────────────────────
    Process {
        id: motionProc
        stdout: SplitParser {
            onRead: line => w.parseMotion(line)
        }
        onExited: {
            w.motionResults = w._motionBuf;
            w.motionHasMore = w._motionBuf.length >= 6;
            w._motionBuf = [];
            w.motionBusy = false;
        }
    }

    function buildMotionUrl() {
        const p = Math.max(1, w.motionPage);
        const q = w.motionQuery.trim();
        if (q.length > 0) {
            const tagSlug = q.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
            if (p > 1 && tagSlug.length > 0)
                return "https://motionbgs.com/tag:" + tagSlug + "/" + p + "/";
            return "https://motionbgs.com/search?q=" + encodeURIComponent(q);
        }
        const cat = w.motionCategory.trim();
        if (cat.length > 0) {
            const catSlug = cat === "cars" ? "car" : (cat === "minimalism" ? "dark" : cat);
            return p === 1
                ? ("https://motionbgs.com/tag:" + encodeURIComponent(catSlug) + "/")
                : ("https://motionbgs.com/tag:" + encodeURIComponent(catSlug) + "/" + p + "/");
        }
        return p === 1 ? "https://motionbgs.com/" : ("https://motionbgs.com/" + p + "/");
    }

    function _fetchMotion() {
        w._motionBuf = [];
        w.motionBusy = true;
        const p = Math.max(1, w.motionPage);
        const q = w.motionQuery.trim();
        const cat = w.motionCategory.trim();
        const primaryUrl = w.buildMotionUrl();
        let fallbackUrl = "";
        if (q.length > 0) {
            const tagSlug = q.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
            if (tagSlug.length > 0)
                fallbackUrl = p === 1
                    ? ("https://motionbgs.com/tag:" + tagSlug + "/")
                    : ("https://motionbgs.com/search?q=" + encodeURIComponent(q));
        } else if (cat.length > 0 && p > 1) {
            const catSlug = cat === "cars" ? "car" : (cat === "minimalism" ? "dark" : cat);
            fallbackUrl = "https://motionbgs.com/tag:" + encodeURIComponent(catSlug) + "/";
        } else if (p > 1) {
            fallbackUrl = "https://motionbgs.com/";
        }
        const ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36";
        motionProc.command = ["sh", "-c",
            "out=$(curl -fsSL -A " + shq(ua) + " --max-time 25 \"$1\" 2>/dev/null | grep -oE '/i/c/364x205/media/[0-9]+/[A-Za-z0-9._-]+' | grep -v '\\.webp$' | awk '!seen[$0]++' | head -200); " +
            "if [ -z \"$out\" ] && [ -n \"$2\" ]; then " +
            "  out=$(curl -fsSL -A " + shq(ua) + " --max-time 25 \"$2\" 2>/dev/null | grep -oE '/i/c/364x205/media/[0-9]+/[A-Za-z0-9._-]+' | grep -v '\\.webp$' | awk '!seen[$0]++' | head -200); " +
            "fi; " +
            "printf '%s\\n' \"$out\"",
            "oberon-motion", primaryUrl, fallbackUrl
        ];
        motionProc.running = false;
        motionProc.running = true;
    }

    function motionGoPage(p) {
        w.motionPage = Math.max(1, Math.round(p));
        w._fetchMotion();
    }

    function motionNextPage() {
        w.motionGoPage(w.motionPage + 1);
    }

    function motionPrevPage() {
        if (w.motionPage > 1)
            w.motionGoPage(w.motionPage - 1);
    }

    function motionSetCategory(cat) {
        w.motionCategory = String(cat || "");
        w.motionQuery = "";
        w.motionPage = 1;
        w._fetchMotion();
    }

    function motionSearch(q) {
        if (q !== undefined)
            w.motionQuery = String(q);
        w.motionPage = 1;
        w._fetchMotion();
    }

    function searchMotion() {
        w.motionSearch(w.motionQuery);
    }

    function loadMoreMotion() {
        if (w.motionBusy) return;
        w.motionNextPage();
    }

    function parseMotion(path) {
        const s = path.trim();
        const m = s.match(/\/media\/([0-9]+)\/([A-Za-z0-9._-]+)$/);
        if (!m) return;
        const id = m[1];
        const file = m[2].replace(/\.webp$/i, "");
        let slug = file;
        const dot = slug.lastIndexOf(".");
        if (dot > 0) slug = slug.slice(0, dot);
        slug = slug.replace(/\.\d+x\d+$/, "");
        for (const it of w._motionBuf) {
            if (it.id === id) return;
        }
        const thumbPath = s.indexOf("/i/c/") === 0 ? s.replace(/\.webp$/i, "") : ("/i/c/364x205/media/" + id + "/" + file);
        const videoUrl = "https://motionbgs.com/media/" + id + "/" + slug + ".1920x1080.mp4";
        w._motionBuf.push({
            id: id,
            slug: slug,
            name: slug.replace(/-/g, " "),
            resolution: "LIVE",
            thumb: "https://motionbgs.com" + thumbPath,
            video: videoUrl,
            path: videoUrl
        });
    }

    // ── Download & Apply (Wallhaven & MotionBGs & Local) ───────────────
    Process {
        id: dlProc
        property string url: ""
        property string dest: ""
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\" && " +
            "{ [ -s \"$2\" ] || { curl -fsSL --max-time 120 -o \"$2.part\" \"$1\" && mv -f \"$2.part\" \"$2\"; }; }",
            "oberon-wh-dl", dlProc.url, dlProc.dest
        ]
        onExited: (code) => {
            w.applying = false;
            if (code === 0 && dlProc.dest.length > 0)
                w.apply(dlProc.dest, false);
        }
    }

    Process {
        id: dlVideoProc
        property string url: ""
        property string dest: ""
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\" && " +
            "{ [ -s \"$2\" ] || { curl -fsSL --max-time 180 -o \"$2.part\" \"$1\" && mv -f \"$2.part\" \"$2\"; }; }",
            "oberon-motion-dl", dlVideoProc.url, dlVideoProc.dest
        ]
        onExited: (code) => {
            w.applying = false;
            if (code === 0 && dlVideoProc.dest.length > 0) {
                w.apply(dlVideoProc.dest, true);
                w.refreshLocal();
            }
        }
    }

    function applyWallhaven(item) {
        if (!item) return;
        const url = typeof item === "string" ? item : (item.path || item.full || "");
        if (url.length === 0) return;
        let ext = "jpg";
        const extMatch = url.match(/\.([A-Za-z0-9]+)(?:\?.*)?$/);
        if (extMatch) {
            ext = extMatch[1].toLowerCase();
        } else if (item.type && item.type.indexOf("png") !== -1) {
            ext = "png";
        }
        let id = (typeof item === "object" && item.id) ? String(item.id) : "";
        if (id.length === 0) {
            const base = url.split("/").pop() || ("wh-" + Date.now());
            id = base.replace(/\.[A-Za-z0-9]+$/, "").replace(/[^A-Za-z0-9_-]/g, "");
        }
        const dir = Quickshell.env("HOME") + "/.cache/oberon/wallpapers";
        dlProc.dest = dir + "/" + id + "." + ext;
        dlProc.url = url;
        w.applying = true;
        dlProc.running = false;
        dlProc.running = true;
    }

    function applyUrl(item) {
        w.applyWallhaven(item);
    }

    function applyVideoUrl(url) {
        if (!url || url.length === 0) return;
        if (url.indexOf("http://") !== 0 && url.indexOf("https://") !== 0) {
            w.apply(url, true);
            return;
        }
        let slug = url.split("/").pop() || ("video-" + Date.now());
        slug = slug.replace(/\.mp4$/i, "").replace(/\.\d+x\d+$/, "").replace(/[^A-Za-z0-9._-]/g, "-");
        const m = url.match(/\/media\/([0-9]+)\//);
        if (m && slug.indexOf(m[1]) !== 0)
            slug = m[1] + "-" + slug;
        const dir = Quickshell.env("HOME") + "/.cache/oberon/wallpapers";
        dlVideoProc.dest = dir + "/motion-" + slug + ".mp4";
        dlVideoProc.url = url;
        w.applying = true;
        dlVideoProc.running = false;
        dlVideoProc.running = true;
    }

    function apply(path, isVideo) {
        if (!path || path.length === 0) return;
        if (path.indexOf("http://") === 0 || path.indexOf("https://") === 0) {
            if (isVideo)
                w.applyVideoUrl(path);
            else
                w.applyWallhaven({ path: path, full: path });
            return;
        }
        w.currentPath = path;
        w.currentIsVideo = !!isVideo;
        if (isVideo) {
            Quickshell.execDetached(["sh", "-c",
                "export PATH=\"$HOME/oberon/build/prefix/bin:$HOME/.local/bin:$PATH\"; " +
                "pkill -9 -x mpvpaper 2>/dev/null; pkill -9 -x oberonwall-daem 2>/dev/null; sleep 0.2; " +
                "setsid mpvpaper -f -o 'no-audio loop' '*' " + shq(path) + " >/dev/null 2>&1"]);
        } else {
            Quickshell.execDetached(["sh", "-c",
                "export PATH=\"$HOME/oberon/build/prefix/bin:$HOME/.local/bin:$PATH\"; " +
                "pkill -9 -x mpvpaper 2>/dev/null; " +
                "pgrep -x oberonwall-daem >/dev/null || { setsid \"$HOME/oberon/build/prefix/bin/oberonwall-daemon\" >/dev/null 2>&1 & sleep 0.6; }; " +
                "\"$HOME/oberon/build/prefix/bin/oberonwall\" img " + shq(path) + " --transition-type any --transition-duration 1 >/dev/null 2>&1"]);
        }
        runMatugen(path, !!isVideo);
        saveState();
    }

    // Recolour the system + shell from the wallpaper via matugen / set-theme.sh.
    function runMatugen(path, isVideo) {
        if (isVideo) {
            Quickshell.execDetached(["sh", "-c",
                "ffmpeg -y -ss 3 -i " + shq(path) + " -frames:v 1 -vf scale=640:-1 /tmp/oberon-frame.png >/dev/null 2>&1; " +
                "sh " + shq(Quickshell.env("HOME") + "/oberon/scripts/set-theme.sh") + " /tmp/oberon-frame.png"]);
        } else {
            Quickshell.execDetached(["sh", "-c",
                "sh " + shq(Quickshell.env("HOME") + "/oberon/scripts/set-theme.sh") + " " + shq(path)]);
        }
    }

    // Re-run theme extraction on current wallpaper without restarting wallpaper daemons.
    property bool _themeOnlyPending: false
    function applyThemeOnly() {
        if (_themeOnlyPending) return;
        _themeOnlyPending = true;
        Qt.callLater(() => {
            _themeOnlyPending = false;
            const p = currentPath;
            if (p.length === 0) return;
            runMatugen(p, currentIsVideo);
        });
    }

    function saveState() {
        const json = JSON.stringify({
            path: w.currentPath,
            video: w.currentIsVideo,
            auto: w.autoEnabled,
            autoMin: w.autoMinutes
        });
        const path = Quickshell.stateDir + "/wallpaper.json";
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + shq(Quickshell.stateDir) +
            " && printf %s " + shq(json) + " > " + shq(path + ".tmp") +
            " && mv -f " + shq(path + ".tmp") + " " + shq(path)]);
    }

    function restoreOnStartup(path, isVideo) {
        if (!path || path.length === 0) return;
        w.currentPath = path;
        w.currentIsVideo = !!isVideo;
        const themeScript = Quickshell.env("HOME") + "/oberon/scripts/set-theme.sh";
        const colorsFile = Quickshell.env("HOME") + "/.cache/oberon/colors.json";
        if (isVideo) {
            Quickshell.execDetached(["sh", "-c",
                "export PATH=\"$HOME/oberon/build/prefix/bin:$HOME/.local/bin:$PATH\"; " +
                "if ! pgrep -x mpvpaper >/dev/null 2>&1; then " +
                "  pkill -9 -x oberonwall-daem 2>/dev/null; sleep 0.2; " +
                "  setsid mpvpaper -f -o 'no-audio loop' '*' " + shq(path) + " >/dev/null 2>&1; " +
                "fi; " +
                "if [ ! -s " + shq(colorsFile) + " ]; then " +
                "  ffmpeg -y -ss 3 -i " + shq(path) + " -frames:v 1 -vf scale=640:-1 /tmp/oberon-frame.png >/dev/null 2>&1; " +
                "  sh " + shq(themeScript) + " /tmp/oberon-frame.png; " +
                "fi"]);
        } else {
            Quickshell.execDetached(["sh", "-c",
                "export PATH=\"$HOME/oberon/build/prefix/bin:$HOME/.local/bin:$PATH\"; " +
                "if ! pgrep -x oberonwall-daem >/dev/null 2>&1; then " +
                "  pkill -9 -x mpvpaper 2>/dev/null; " +
                "  setsid \"$HOME/oberon/build/prefix/bin/oberonwall-daemon\" >/dev/null 2>&1 & sleep 0.6; " +
                "  \"$HOME/oberon/build/prefix/bin/oberonwall\" img " + shq(path) + " --transition-type none >/dev/null 2>&1; " +
                "fi; " +
                "if [ ! -s " + shq(colorsFile) + " ]; then " +
                "  sh " + shq(themeScript) + " " + shq(path) + "; " +
                "fi"]);
        }
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
                    if (j.path) w.restoreOnStartup(j.path, !!j.video);
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        refreshLocal();
        searchWallhaven();
        restoreProc.running = true;
    }
}
