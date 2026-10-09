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

    function workspacesFor(output) {
        const out = [];
        for (let i = 0; i < workspaces.length; i++)
            if (workspaces[i].output === output) out.push(workspaces[i]);
        out.sort((a, b) => a.index - b.index);
        return out;
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
