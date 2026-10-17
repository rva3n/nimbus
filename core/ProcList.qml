pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Список процессов для диспетчера задач: ps каждые 2 секунды, действия через kill/renice.
// Поддерживает паузу обновления (paused) и сбор потоков (nlwp), RSS и состояния (R/S/D/Z/T).
Singleton {
    id: p

    property var items: []   // [{user, pid, ppid, ni, threads, nlwp, cpu, mem, rss, rssKb, stat, state, comm, args, name}]
    readonly property int totalCount: p.items ? p.items.length : 0
    property bool loading: false
    property bool active: false
    property bool paused: false

    // накопитель текущего прогона ps — items меняется один раз за цикл
    property var _buf: []

    onPausedChanged: {
        if (!p.paused && p.active)
            p.refresh();
    }

    function refresh() {
        if (psProc.running)
            return;
        p._buf = [];
        p.loading = true;
        psProc.running = true;
    }

    Process {
        id: psProc
        // Имя берём из argv[0] (/proc/<pid>/cmdline, NUL-разделитель) или /proc/<pid>/comm:
        // comm у Proton-игр = MainThread, а args с пробелами в пути не разобрать.
        command: ["bash", "-c",
            "ps -eo pid=,ppid=,user=,stat=,ni=,nlwp=,pcpu=,pmem=,rss=,comm=,args= --sort=-pcpu 2>/dev/null | " +
            "while read -r pid ppid user stat ni nlwp cpu mem rss comm rest; do " +
            "IFS= read -r -d '' cmd0 2>/dev/null < \"/proc/$pid/cmdline\" || cmd0=''; " +
            "IFS= read -r kcomm 2>/dev/null < \"/proc/$pid/comm\" || kcomm=\"$comm\"; " +
            "name=\"$cmd0\"; " +
            "if [ -z \"$name\" ]; then name=\"${kcomm:-$comm}\"; fi; " +
            "printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' " +
            "\"$pid\" \"$ppid\" \"$user\" \"$stat\" \"$ni\" \"$nlwp\" \"$cpu\" \"$mem\" \"$rss\" \"${kcomm:-$comm}\" \"$name\" \"${rest:-$comm}\"; " +
            "done"]
        stdout: SplitParser {
            onRead: line => p._line(line)
        }
        onExited: {
            if (!p.paused || p.items.length === 0)
                p.items = p._buf;
            p.loading = false;
        }
    }

    Timer {
        interval: 2000
        running: p.active && !p.paused
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!p.active || p.paused || psProc.running)
                return;
            p.refresh();
        }
    }

    // имя исполняемого файла: argv[0] может быть путём с пробелами
    // (S:\steamapps\common\The Witcher 3\...\witcher3.exe), поэтому режем по
    // последнему разделителю пути, а не по первому пробелу
    function _name(exe) {
        let s = String(exe).trim();
        if ((s.length >= 2) && ((s[0] === '"' && s[s.length - 1] === '"') || (s[0] === "'" && s[s.length - 1] === "'")))
            s = s.slice(1, s.length - 1);
        const parts = s.split(/[\\/]/);
        const last = parts[parts.length - 1];
        return last !== "" ? last : s;
    }

    function _line(line) {
        const f = line.split("\t");
        if (f.length < 12)
            return;
        const statStr = String(f[3] || "S").trim();
        const stateChar = (statStr[0] || "S").toUpperCase();
        const nlwpVal = Math.max(1, parseInt(f[5], 10) || 1);
        const rssKbVal = Math.max(0, parseInt(f[8], 10) || 0);
        const commStr = String(f[9] || "").trim();
        const rawName = String(f[10] || "").trim();
        const argsStr = String(f[11] || commStr).trim();

        p._buf.push({
            pid: parseInt(f[0], 10) || 0,
            ppid: parseInt(f[1], 10) || 0,
            user: String(f[2] || "").trim(),
            stat: statStr,
            state: stateChar,
            ni: parseInt(f[4], 10) || 0,
            threads: nlwpVal,
            nlwp: nlwpVal,
            cpu: parseFloat(String(f[6]).replace(",", ".")) || 0,
            mem: parseFloat(String(f[7]).replace(",", ".")) || 0,
            rssKb: rssKbVal,
            rss: rssKbVal * 1024,
            comm: commStr,
            args: argsStr,
            name: p._name(rawName !== "" ? rawName : (commStr !== "" ? commStr : argsStr))
        });
    }

    // ── действия над процессом (контекстное меню и тулбар) ─────────────
    function stop(pid) { Quickshell.execDetached(["kill", "-STOP", String(pid)]); }
    function cont(pid) { Quickshell.execDetached(["kill", "-CONT", String(pid)]); }
    function term(pid) { Quickshell.execDetached(["kill", "-TERM", String(pid)]); }
    function kill9(pid) { Quickshell.execDetached(["kill", "-KILL", String(pid)]); }
    function renice(pid, n) { Quickshell.execDetached(["renice", String(Math.max(-20, Math.min(19, n))), "-p", String(pid)]); }
    function copyPid(pid) { Quickshell.execDetached(["sh", "-c", "printf %s " + pid + " | wl-copy"]); }
}
