pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Список процессов для диспетчера задач: ps каждые 2 секунды, действия через kill/renice.
Singleton {
    id: p

    property var items: []   // [{user, pid, ni, cpu, mem, stat, name}]
    property bool loading: false

    Process {
        id: psProc
        command: ["sh", "-c", "ps -eo user:16,pid,ni,pcpu,pmem,stat,comm --sort=-pcpu --no-headers 2>/dev/null | head -80"]
        stdout: SplitParser {
            onRead: line => p._line(line)
        }
        onExited: p.loading = false
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            p.items = [];
            p.loading = true;
            psProc.running = false;
            psProc.running = true;
        }
    }

    function _line(line) {
        const m = line.match(/^(\S+)\s+(\d+)\s+(-?\d+)\s+([\d.,]+)\s+([\d.,]+)\s+(\S+)\s+(.+)$/);
        if (!m)
            return;
        const arr = p.items.slice();
        arr.push({
            user: m[1],
            pid: parseInt(m[2], 10),
            ni: parseInt(m[3], 10),
            cpu: parseFloat(String(m[4]).replace(",", ".")),
            mem: parseFloat(String(m[5]).replace(",", ".")),
            stat: m[6],
            name: m[7]
        });
        p.items = arr;
    }

    // ── действия над процессом (контекстное меню) ──────────────────────
    function stop(pid) { Quickshell.execDetached(["kill", "-STOP", String(pid)]); }
    function cont(pid) { Quickshell.execDetached(["kill", "-CONT", String(pid)]); }
    function term(pid) { Quickshell.execDetached(["kill", "-TERM", String(pid)]); }
    function kill9(pid) { Quickshell.execDetached(["kill", "-KILL", String(pid)]); }
    function renice(pid, n) { Quickshell.execDetached(["renice", String(Math.max(-20, Math.min(19, n))), "-p", String(pid)]); }
    function copyPid(pid) { Quickshell.execDetached(["sh", "-c", "printf %s " + pid + " | wl-copy"]); }
}
