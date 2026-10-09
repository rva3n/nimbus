pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Системные метрики: CPU, память, диск, температура, uptime.
// Читается из /proc и df раз в две секунды.
Singleton {
    id: s

    property real cpu: 0          // 0..1
    property real memUsed: 0      // байты
    property real memTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property real tempC: -1
    property int uptime: 0        // секунды
    property string host: ""
    property string kernel: ""

    readonly property real memFrac: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real diskFrac: diskTotal > 0 ? diskUsed / diskTotal : 0

    property var _prevCpu: null

    function _cpuTick(line) {
        // user nice system idle iowait irq softirq steal
        const v = line.split(/\s+/).filter(x => x !== "").slice(0, 8).map(Number);
        if (v.length < 8)
            return;

        const total = v.reduce((a, b) => a + b, 0);
        const idle = v[3] + (v[4] || 0);
        if (s._prevCpu) {
            const dt = total - s._prevCpu.total;
            const di = idle - s._prevCpu.idle;
            if (dt > 0)
                s.cpu = Math.max(0, Math.min(1, 1 - di / dt));
        }
        s._prevCpu = { total: total, idle: idle };
    }

    function _line(line) {
        if (line.startsWith("CPU "))
            s._cpuTick(line.slice(4));
        else if (line.startsWith("MEM ")) {
            const p = line.split(/\s+/);
            s.memTotal = (+p[1]) * 1024;
            s.memUsed = ((+p[1]) - (+p[2])) * 1024;
        } else if (line.startsWith("DISK ")) {
            const p = line.split(/\s+/);
            s.diskTotal = +p[1];
            s.diskUsed = +p[2];
        } else if (line.startsWith("TEMP ")) {
            const t = +(line.slice(5));
            s.tempC = t > 1000 ? t / 1000 : t;
        } else if (line.startsWith("UP "))
            s.uptime = +line.slice(3);
        else if (line.startsWith("HOST "))
            s.host = line.slice(5);
        else if (line.startsWith("KERN "))
            s.kernel = line.slice(5);
    }

    Process {
        id: proc
        command: ["sh", "-c",
            "echo \"CPU $(awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat)\"; " +
            "echo \"MEM $(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t,a}' /proc/meminfo)\"; " +
            "echo \"DISK $(df -B1 /home/tony | awk 'NR==2{print $2,$3}')\"; " +
            "echo \"UP $(cut -d. -f1 /proc/uptime)\"; " +
            "echo \"HOST $(uname -n)\"; " +
            "echo \"KERN $(uname -r)\"; " +
            "T=$(for z in /sys/class/thermal/thermal_zone*/temp; do [ -r \"$z\" ] && cat \"$z\" && break; done); echo \"TEMP ${T:-0}\""]
        stdout: SplitParser {
            onRead: line => s._line(line)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            proc.running = false;
            proc.running = true;
        }
    }
}
