pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live state from the Umbriel compositor via `umbriel subscribe`.
Singleton {
    id: root

    property var workspaces: []
    property var windows: []
    property var activeWindow: null
    property string keyboardLayout: ""

    // «English (US)» → US, «Russian» → RU
    function shortLayout(name) {
        const s = String(name || "");
        if (s.indexOf("English") === 0)
            return "US";
        if (s.indexOf("Russian") === 0)
            return "RU";
        return s.length >= 2 ? s.slice(0, 2).toUpperCase() : s.toUpperCase();
    }

    function _layout(line) {
        try {
            const m = JSON.parse(line);
            if (m.event === "keyboard_layout" && m.data && m.data.names) {
                const i = m.data.current_index || 0;
                root.keyboardLayout = root.shortLayout(m.data.names[i] || "");
            }
        } catch (e) {}
    }

    Process {
        id: layoutProc
        running: true
        command: ["umbriel", "subscribe", "keyboard_layout"]
        stdout: SplitParser {
            onRead: line => root._layout(line)
        }
    }

    function workspacesFor(output) {
        const out = [];
        for (let i = 0; i < workspaces.length; i++)
            if (workspaces[i].output === output) out.push(workspaces[i]);
        out.sort((a, b) => a.index - b.index);
        return out;
    }

    // уникальные приложения на воркспейсе (для иконок в точках воркспейсов)
    function appsFor(workspaceId) {
        const seen = {};
        const out = [];
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            if (w.workspace !== workspaceId || !w.app_id) continue;
            if (seen[w.app_id]) continue;
            seen[w.app_id] = true;
            out.push({ app_id: w.app_id, title: w.title || "" });
        }
        return out;
    }

    // Активное окно во весь экран (для авто-скрытия острова): отдельного поля
    // у Umbriel нет, поэтому смотрим геометрию активного окна на этом output.
    function fullscreenFor(output, w, h) {
        const a = activeWindow;
        if (!output || !a)
            return false;
        if (String(a.workspace || "").indexOf(output + ":") !== 0)
            return false;
        return a.w >= w - 2 && a.h >= h - 2 && a.x <= 2 && a.y <= 2;
    }

    function _workspaces(line) {
        try {
            const m = JSON.parse(line);
            if (m.event === "workspaces" && m.data) root.workspaces = m.data;
        } catch (e) {}
    }
    function _windows(line) {
        try {
            const m = JSON.parse(line);
            if (m.event === "windows" && m.data) {
                root.windows = m.data;
                let act = null;
                for (let i = 0; i < m.data.length; i++)
                    if (m.data[i].active) { act = m.data[i]; break; }
                root.activeWindow = act;
            }
        } catch (e) {}
    }

    Process {
        id: wsProc
        running: true
        command: ["umbriel", "subscribe", "workspaces"]
        stdout: SplitParser { onRead: line => root._workspaces(line) }
    }
    Process {
        id: winProc
        running: true
        command: ["umbriel", "subscribe", "windows"]
        stdout: SplitParser { onRead: line => root._windows(line) }
    }
}
