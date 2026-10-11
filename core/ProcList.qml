pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Список процессов для диспетчера задач: ps каждые 2 секунды, действия через kill/renice.
// Дерево строится по ppid во вкладке «Диспетчер»; здесь только «плоский» срез (ppid хранится).
Singleton {
    id: p

    property var items: []   // [{user, pid, ppid, ni, cpu, mem, stat, args, name}]
    property bool loading: false

    // накопитель текущего прогона ps — items меняется один раз за цикл
    property var _buf: []

    Process {
        id: psProc
        // имя берём из argv[0] (/proc/<pid>/cmdline, NUL-разделитель): comm у
        // Proton-игр = MainThread, а args с пробелами в пути не разобрать.
        command: ["bash", "-c",
            "ps -eo user:16,pid,ppid,ni,pcpu,pmem,stat,args --sort=-pcpu --no-headers 2>/dev/null | " +
            "while read -r user pid ppid ni cpu mem stat rest; do " +
            "IFS= read -r -d '' name 2>/dev/null < \"/proc/$pid/cmdline\"; " +
            "if [ -z \"$name\" ]; then name=\"${rest%% *}\"; fi; " +
            "printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' " +
            "\"$user\" \"$pid\" \"$ppid\" \"$ni\" \"$cpu\" \"$mem\" \"$stat\" \"$name\" \"$rest\"; " +
            "done"]
        stdout: SplitParser {
            onRead: line => p._line(line)
        }
        onExited: {
            p.items = p._buf;
            p.loading = false;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            p._buf = [];
            p.loading = true;
            psProc.running = false;
            psProc.running = true;
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
        if (f.length < 9)
            return;
        const args = f[8];
        p._buf.push({
            user: f[0].trim(),
            pid: parseInt(f[1], 10),
            ppid: parseInt(f[2], 10),
            ni: parseInt(f[3], 10),
            cpu: parseFloat(String(f[4]).replace(",", ".")),
            mem: parseFloat(String(f[5]).replace(",", ".")),
            stat: f[6],
            args: args,
            name: p._name(f[7] !== "" ? f[7] : args)
        });
    }

    // ── действия над процессом (контекстное меню) ──────────────────────
    function stop(pid) { Quickshell.execDetached(["kill", "-STOP", String(pid)]); }
    function cont(pid) { Quickshell.execDetached(["kill", "-CONT", String(pid)]); }
    function term(pid) { Quickshell.execDetached(["kill", "-TERM", String(pid)]); }
    function kill9(pid) { Quickshell.execDetached(["kill", "-KILL", String(pid)]); }
    function renice(pid, n) { Quickshell.execDetached(["renice", String(Math.max(-20, Math.min(19, n))), "-p", String(pid)]); }
    function copyPid(pid) { Quickshell.execDetached(["sh", "-c", "printf %s " + pid + " | wl-copy"]); }
}
