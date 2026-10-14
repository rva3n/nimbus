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
    // id активного воркспейса каждого вывода: {"DP-1": "DP-1:1"}.
    // Берём из события `workspaces`: оно приходит на любое переключение, в том
    // числе на пустой воркспейс, где `windows` может опоздать/не измениться.
    property var activeWorkspaces: ({})

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
        onExited: running = true
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

    function _workspaces(line) {
        try {
            const m = JSON.parse(line);
            if (m.event === "workspaces" && m.data) {
                root.workspaces = m.data;
                const act = {};
                for (let i = 0; i < m.data.length; i++) {
                    const ws = m.data[i];
                    if (ws && ws.active === true && ws.output) act[ws.output] = ws.id;
                }
                root.activeWorkspaces = act;
                // `windows` мог не прийти (пустой воркспейс) — пересчитываем сами
                root.refreshActiveWindow();
            }
        } catch (e) {}
    }
    function _windows(line) {
        try {
            const m = JSON.parse(line);
            if (m.event === "windows" && m.data) {
                root.windows = m.data;
                root.refreshActiveWindow();
            }
        } catch (e) {}
    }

    Process {
        id: wsProc
        running: true
        command: ["umbriel", "subscribe", "workspaces"]
        onExited: running = true
        stdout: SplitParser { onRead: line => root._workspaces(line) }
    }
    Process {
        id: winProc
        running: true
        command: ["umbriel", "subscribe", "windows"]
        onExited: running = true
        stdout: SplitParser { onRead: line => root._windows(line) }
    }
}
