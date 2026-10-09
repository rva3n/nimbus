pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Launcher pin/hide state (persisted).
Singleton {
    id: a

    property var pinned: []
    property var hidden: []
    property bool showHidden: false

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    Process {
        id: readProc
        command: ["sh", "-c", "cat " + shq(Quickshell.stateDir + "/launcher.json") + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    a.pinned = j.pinned || [];
                    a.hidden = j.hidden || [];
                } catch (e) {}
            }
        }
    }
    function load() { readProc.running = false; readProc.running = true; }
    function save() {
        const j = JSON.stringify({ pinned: a.pinned, hidden: a.hidden });
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + shq(Quickshell.stateDir) + "; printf %s " + shq(j) + " > " + shq(Quickshell.stateDir + "/launcher.json")]);
    }

    function keyOf(app) {
        if (app.startupClass && app.startupClass !== "") return app.startupClass;
        return app.name || "";
    }
    function isPinned(app) { return a.pinned.indexOf(keyOf(app)) !== -1; }
    function isHidden(app) { return a.hidden.indexOf(keyOf(app)) !== -1; }
    function togglePin(app) {
        const k = keyOf(app); const arr = a.pinned.slice();
        const i = arr.indexOf(k);
        if (i >= 0) arr.splice(i, 1); else arr.push(k);
        a.pinned = arr; a.save();
    }
    function toggleHide(app) {
        const k = keyOf(app); const arr = a.hidden.slice();
        const i = arr.indexOf(k);
        if (i >= 0) arr.splice(i, 1); else arr.push(k);
        a.hidden = arr; a.save();
    }

    Component.onCompleted: load()
}
