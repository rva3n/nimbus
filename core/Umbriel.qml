pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live state from the Umbriel compositor via `umbriel subscribe`.
Singleton {
    id: root

    property var workspaces: []
    property var windows: []
    property var outputData: []
    property var activeWindow: null
    property string keyboardLayout: ""
    // id активного воркспейса каждого вывода: {"DP-1": "DP-1:1"}.
    // Берём из события `workspaces`: оно приходит на любое переключение, в том
    // числе на пустой воркспейс, где `windows` может опоздать/не измениться.
    property var activeWorkspaces: ({})
    property string layoutMode: "dwindle"
    readonly property string layoutLabel: root.layoutMode === "scrolling" ? "Scrolling"
        : (root.layoutMode === "master" ? "Master" : "Dwindle")

    FileView {
        id: appearanceFile
        path: Quickshell.env("HOME") + "/.config/umbriel/src/appearance.toml"
        watchChanges: true
        onFileChanged: reload()
        onLoadedChanged: {
            if (!appearanceFile.loaded)
                return;
            const m = appearanceFile.text().match(/^\s*mode\s*=\s*"(scrolling|dwindle|master)"/m);
            if (m)
                root.layoutMode = m[1];
        }
    }

    function refreshLayout() {
        appearanceFile.reload();
    }

    function cycleLayout() {
        const order = ["scrolling", "dwindle", "master"];
        const idx = order.indexOf(root.layoutMode);
        const next = order[(idx + 1) % order.length];
        root.layoutMode = next;
        Quickshell.execDetached([
            "python3",
            Quickshell.env("HOME") + "/oberon/scripts/umbriel-settings.py",
            "set", "src/appearance.toml", "layout", "mode", "\"" + next + "\""
        ]);
    }

    readonly property string activeOutput: {
        const list = Array.isArray(root.outputData) ? root.outputData : [];
        for (let i = 0; i < list.length; i++) {
            const output = list[i];
            if (output && output.focused === true && output.name)
                return String(output.name);
        }
        return "";
    }

    // «English (US)» → US, «Russian» → RU
    function shortLayout(name) {
        const s = String(name || "");
        if (s.indexOf("English") === 0)
            return "US";
        if (s.indexOf("Russian") === 0)
            return "RU";
        return s.length >= 2 ? s.slice(0, 2).toUpperCase() : s.toUpperCase();
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

    // Активное окно этого вывода: сначала окно сиденьца (active), иначе окно
    // на АКТИВНОМ воркспейсе вывода. Флаг `focused` сам по себе не годится —
    // он посорспейсный (окно скрытого воркспейса тоже focused=true).
    function activeWindowFor(output) {
        if (!output) return null;
        let fallback = null;
        const wsId = root.activeWorkspaces[output];
        for (let i = 0; i < root.windows.length; i++) {
            const w = root.windows[i];
            if (!w) continue;
            if (w.output !== output && String(w.workspace || "").indexOf(output + ":") !== 0)
                continue;                                 // чужой вывод
            if (w.active === true) return w;              // окно сиденьца
            if (fallback === null && wsId && w.workspace === wsId) fallback = w;
        }
        return fallback;
    }

    // Окно во весь экран на этом output → остров уступает. Сравниваем с
    // активным воркспейсом вывода, а не с «последним активным окном».
    function fullscreenFor(output) {
        const a = root.activeWindowFor(output);
        return !!(a && a.fullscreen === true);
    }

    // activeWindow остаётся свойством (API для прочего UI), но пересчитывается
    // от текущих данных, чтобы не зависнуть на окне ушедшего воркспейса.
    function refreshActiveWindow() {
        let act = null;
        for (let i = 0; i < root.windows.length; i++)
            if (root.windows[i].active === true) { act = root.windows[i]; break; }
        root.activeWindow = act;
    }

    function _handleEvent(line) {
        try {
            const msg = JSON.parse(line);
            if (!msg || typeof msg !== "object")
                return;
            if (msg.event === "keyboard_layout" && msg.data && msg.data.names) {
                const i = msg.data.current_index || 0;
                root.keyboardLayout = root.shortLayout(msg.data.names[i] || "");
            } else if (msg.event === "workspaces" && Array.isArray(msg.data)) {
                root.workspaces = msg.data;
                const act = {};
                for (let i = 0; i < msg.data.length; i++) {
                    const ws = msg.data[i];
                    if (ws && ws.active === true && ws.output)
                        act[ws.output] = ws.id;
                }
                root.activeWorkspaces = act;
                root.refreshActiveWindow();
            } else if (msg.event === "windows" && Array.isArray(msg.data)) {
                root.windows = msg.data;
                root.refreshActiveWindow();
            } else if (msg.event === "outputs" && Array.isArray(msg.data)) {
                root.outputData = msg.data;
            }
        } catch (e) {}
    }

    Process {
        id: subProc
        running: true
        command: ["umbriel", "subscribe", "keyboard_layout,workspaces,windows,outputs"]
        onExited: subRetry.restart()
        stdout: SplitParser {
            onRead: line => root._handleEvent(line)
        }
    }

    Timer {
        id: subRetry
        interval: 1500
        onTriggered: subProc.running = true
    }
}
