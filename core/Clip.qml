pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist + pinned items.
Singleton {
    id: c

    property var items: []
    property var pins: []
    property bool loading: false

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    // Keep capturing the clipboard.
    Process {
        id: storeProc
        command: ["sh", "-c", "wl-paste --watch cliphist store"]
        running: true
    }

    // List entries and decode image thumbnails.
    Process {
        id: scanProc
        command: ["sh", "-c",
            "C=\"$HOME/.cache/nimbus/clip\"; mkdir -p \"$C\"; " +
            "cliphist list 2>/dev/null | head -60 | sed 's/\\t/|/' | while IFS='|' read -r id rest; do " +
            "case \"$rest\" in *\"binary data\"*) cliphist decode \"$id\" > \"$C/$id.png\" 2>/dev/null; printf '%s|image|%s\\n' \"$id\" \"$rest\";; " +
            "*) printf '%s|text|%s\\n' \"$id\" \"$rest\";; esac; done"]
        stdout: SplitParser { onRead: line => c.parseEntry(line) }
        onExited: c.loading = false
    }
    function parseEntry(line) {
        const i = line.indexOf("|"); if (i < 0) return;
        const j = line.indexOf("|", i + 1); if (j < 0) return;
        const id = line.slice(0, i);
        const arr = c.items.slice();
        arr.push({
            id: id,
            type: line.slice(i + 1, j),
            preview: line.slice(j + 1),
            thumb: Quickshell.env("HOME") + "/.cache/nimbus/clip/" + id + ".png"
        });
        c.items = arr;
    }

    Process {
        id: pinsProc
        // jq -c: файл пишется многострочным, а SplitParser читает по строкам
        command: ["sh", "-c", "cat " + shq(Quickshell.env("HOME") + "/.local/state/nimbus/pins.json") + " 2>/dev/null | jq -c . 2>/dev/null"]
        stdout: SplitParser { onRead: line => { try { c.pins = JSON.parse(line); } catch (e) { c.pins = []; } } }
    }
    function loadPins() { pinsProc.running = false; pinsProc.running = true; }

    function refresh() { c.items = []; c.loading = true; scanProc.running = false; scanProc.running = true; c.loadPins(); }

    function copy(id, type) {
        const mime = (type === "image") ? " --type image/png" : "";
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + shq(id) + " | wl-copy" + mime]);
    }
    function del(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist list | grep -m1 -P '^" + id + "\\t' | cliphist delete"]);
    }
    function wipe() { Quickshell.execDetached(["sh", "-c", "cliphist wipe"]); c.items = []; }
    function pin(id) { Quickshell.execDetached(["sh", "-c", "bash " + shq(Quickshell.configDir + "/scripts/clip-pin.sh") + " " + shq(id)]); }
    function unpin(id) { Quickshell.execDetached(["sh", "-c", "bash " + shq(Quickshell.configDir + "/scripts/clip-unpin.sh") + " " + shq(id)]); }
    function copyPin(p) {
        if (p.type === "image") Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + shq(p.file)]);
        else Quickshell.execDetached(["sh", "-c", "printf %s " + shq(p.text) + " | wl-copy"]);
    }
}
