pragma Singleton
import QtQuick
import Quickshell

// Notification history + transient toast state.
Singleton {
    id: root

    property var history: []      // newest first
    property var current: null    // toast content
    property bool visible: false  // toast shown in the island
    property bool dnd: false

    Timer {
        id: hideTimer
        interval: 4500
        onTriggered: root.visible = false
    }

    function add(n) {
        const h = history.slice();
        h.unshift(n);
        root.history = h.slice(0, 12);
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
        }
    }
    function clearAll() {
        for (const item of root.history) if (item && item.raw) { try { item.raw.dismiss(); } catch (e) {} }
        root.history = [];
        root.visible = false;
    }
}
