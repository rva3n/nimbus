pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Notification history + transient toast state (history persisted).
Singleton {
    id: root

    property var history: []      // newest first
    property var current: null    // toast content
    property bool visible: false  // toast shown in the island
    property bool dnd: Prefs.dnd  // персистится в prefs.json (пишется через Prefs.set)

    readonly property string statePath: Quickshell.stateDir + "/notifs.json"

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    // Only serializable fields of history items are kept (raw is a live object).
    function serialize() {
        const out = [];
        for (const item of root.history) {
            if (!item) continue;
            out.push({
                appName: item.appName || "",
                summary: item.summary || "",
                body: item.body || "",
                appIcon: item.appIcon || "",
                ts: item.ts || 0
            });
        }
        return JSON.stringify(out);
    }

    function save() {
        const j = serialize();
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p " + shq(Quickshell.stateDir) + "; printf %s " + shq(j) + " > " + shq(root.statePath)]);
    }
    // Debounced write: coalesces bursts of add/dismiss/clear.
    function scheduleSave() { saveTimer.restart(); }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: root.save()
    }

    Process {
        id: readProc
        command: ["sh", "-c", "cat " + shq(root.statePath) + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    if (Array.isArray(j)) root.history = j.slice(0, 12);
                } catch (e) {}
            }
        }
    }
    function load() { readProc.running = false; readProc.running = true; }

    Component.onCompleted: load()

    Timer {
        id: hideTimer
        interval: Math.max(2, Prefs.toastSeconds) * 1000
        onTriggered: root.visible = false
    }

    function add(n) {
        const h = history.slice();
        h.unshift(n);
        root.history = h.slice(0, 12);
        scheduleSave();
    }
    function toast(n) {
        root.current = n;
        root.visible = true;
        hideTimer.restart();
    }
    function push(n) { add(n); toast(n); }
    function dismissAt(i) {
        const h = root.history.slice();
        if (i >= 0 && i < h.length) {
            const item = h[i];
            if (item && item.raw) { try { item.raw.dismiss(); } catch (e) {} }
            h.splice(i, 1);
            root.history = h;
            scheduleSave();
        }
    }
    function clearAll() {
        for (const item of root.history) if (item && item.raw) { try { item.raw.dismiss(); } catch (e) {} }
        root.history = [];
        root.visible = false;
        scheduleSave();
    }
}
