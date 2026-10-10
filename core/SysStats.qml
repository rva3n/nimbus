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

    // GPU (amdgpu)
    property real gpuBusy: 0      // 0..1
    property real vramUsed: 0     // байты
    property real vramTotal: 0
    property real gpuTempC: -1
    property real gpuPowerW: -1

    // дополнительные метрики (компактная страница «Система»)
    property real load1: 0
    property real load5: 0
    property int procCount: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property int cpuCurMhz: 0
    property int cpuMaxMhz: 0
    property int gpuSclkMhz: 0
    property int gpuFanRpm: 0
    // для диспетчера задач
    property int cores: 0
    property string cpuModel: ""
    property string gpuModel: ""
    property string distro: ""
    property var temps: []   // [{name, label, c}]
    property var disks: []   // [{mount, used, total}]

    readonly property real memFrac: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real diskFrac: diskTotal > 0 ? diskUsed / diskTotal : 0
    readonly property real vramFrac: vramTotal > 0 ? vramUsed / vramTotal : 0
    readonly property real swapFrac: swapTotal > 0 ? swapUsed / swapTotal : 0

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
        } else if (line.startsWith("GPUB ")) {
            s.gpuBusy = Math.max(0, Math.min(1, (+line.slice(5)) / 100));
        } else if (line.startsWith("VRAM ")) {
            const p = line.split(/\s+/);
            s.vramUsed = +p[1];
            s.vramTotal = +p[2];
        } else if (line.startsWith("GTEMP ")) {
            const g = +(line.slice(6));
            s.gpuTempC = g > 1000 ? g / 1000 : g;
        } else if (line.startsWith("GPOW ")) {
            const w = +(line.slice(5));
            s.gpuPowerW = w > 0 ? w / 1000000 : -1;
        } else if (line.startsWith("LOAD ")) {
            const p = line.split(/\s+/);
            s.load1 = +p[1];
            s.load5 = +p[2];
        } else if (line.startsWith("PROCS ")) {
            s.procCount = +line.slice(6);
        } else if (line.startsWith("SWAP ")) {
            const p = line.split(/\s+/);
            s.swapTotal = (+p[1]) * 1024;
            s.swapUsed = ((+p[1]) - (+p[2])) * 1024;
        } else if (line.startsWith("CPUF ")) {
            const p = line.split(/\s+/);
            s.cpuCurMhz = Math.round((+p[1]) / 1000);
            s.cpuMaxMhz = Math.round((+p[2]) / 1000);
        } else if (line.startsWith("GCLK ")) {
            s.gpuSclkMhz = +line.slice(5);
        } else if (line.startsWith("GFAN ")) {
            s.gpuFanRpm = +line.slice(5);
        } else if (line.startsWith("CORES ")) {
            s.cores = +line.slice(6);
        } else if (line.startsWith("DISKS ")) {
            const parts = line.slice(6).split("|");
            const out = [];
            for (let i = 0; i + 2 < parts.length; i += 3)
                out.push({ mount: parts[i], total: +parts[i + 1], used: +parts[i + 2] });
            s.disks = out;
        } else if (line.startsWith("TEMP ")) {
            const p = line.slice(5).split("|");
            let v = +p[2];
            if (v > 1000) v /= 1000;
            const arr = s.temps.slice();
            // у одного hwmon несколько датчиков: имя с подписью, если есть
            arr.push({ name: p[0] || "", label: p[1] || "", c: v });
            s.temps = arr;
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
            "echo \"DISK $(df -B1 \"$HOME\" | awk 'NR==2{print $2,$3}')\"; " +
            "echo \"UP $(cut -d. -f1 /proc/uptime)\"; " +
            "echo \"HOST $(uname -n)\"; " +
            "echo \"KERN $(uname -r)\"; " +
            "T=$(for z in /sys/class/thermal/thermal_zone*/temp; do [ -r \"$z\" ] && cat \"$z\" && break; done); echo \"TEMP ${T:-0}\"; " +
            "B=$(for f in /sys/class/drm/card[0-9]*/device/gpu_busy_percent; do [ -r \"$f\" ] && cat \"$f\" && break; done); echo \"GPUB ${B:-0}\"; " +
            "V=$(for f in /sys/class/drm/card[0-9]*/device/mem_info_vram_used; do [ -r \"$f\" ] && cat \"$f\" && break; done); " +
            "V2=$(for f in /sys/class/drm/card[0-9]*/device/mem_info_vram_total; do [ -r \"$f\" ] && cat \"$f\" && break; done); echo \"VRAM ${V:-0} ${V2:-0}\"; " +
            "GT=$(for f in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp1_input; do [ -r \"$f\" ] && cat \"$f\" && break; done); echo \"GTEMP ${GT:-0}\"; " +
            "GP=$(for f in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/power1_average; do [ -r \"$f\" ] && cat \"$f\" && break; done); echo \"GPOW ${GP:-0}\"; " +
            "L=$(cut -d' ' -f1,2 /proc/loadavg); echo \"LOAD $L\"; " +
            "echo \"PROCS $(ps -e --no-headers 2>/dev/null | wc -l)\"; " +
            "SW=$(awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print t,f}' /proc/meminfo); echo \"SWAP $SW\"; " +
            "CF=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0); CM=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0); echo \"CPUF ${CF:-0} ${CM:-0}\"; " +
            "GS=$(for f in /sys/class/drm/card[0-9]*/device/pp_dpm_sclk; do [ -r \"$f\" ] && awk '/[*]/{print $2; exit}' \"$f\" && break; done | tr -dc 0-9); echo \"GCLK ${GS:-0}\"; " +
            "GF=$(for f in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/fan1_input; do [ -r \"$f\" ] && cat \"$f\" && break; done); echo \"GFAN ${GF:-0}\"; " +
            "echo \"CORES $(nproc 2>/dev/null || echo 0)\"; " +
            "echo \"DISKS $(df -B1 -x tmpfs -x devtmpfs -x squashfs -x efivarfs -x overlay --output=target,size,used 2>/dev/null | tail -n +2 | grep '^/' | paste -sd'|' -)\"; " +
            "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); for f in \"$d\"/temp*_input; do [ -r \"$f\" ] || continue; l=\"${f%_input}_label\"; lab=''; [ -r \"$l\" ] && lab=$(cat \"$l\" 2>/dev/null); printf 'TEMP %s|%s|%s\\n' \"$n\" \"$lab\" \"$(cat \"$f\")\"; done; done"]
        stdout: SplitParser {
            onRead: line => s._line(line)
        }
    }

    // Статичная информация о железе и системе (для «О системе» диспетчера)
    Process {
        id: staticProc
        running: true
        command: ["sh", "-c",
            "echo \"DISTRO $(. /etc/os-release 2>/dev/null; printf '%s' \"$PRETTY_NAME\")\"; " +
            "echo \"CPU $(awk -F: '/model name/{gsub(/^ +/,\"\",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null)\"; " +
            "G=$(lspci 2>/dev/null | grep -iE 'vga|3d controller' | head -1 | cut -d: -f3- | sed 's/^ //'); echo \"GPU ${G:-}\""]
        stdout: SplitParser {
            onRead: line => s._staticLine(line)
        }
    }

    function _staticLine(line) {
        if (line.startsWith("DISTRO "))
            s.distro = line.slice(7).trim();
        else if (line.startsWith("CPU "))
            s.cpuModel = line.slice(4).trim();
        else if (line.startsWith("GPU "))
            s.gpuModel = line.slice(4).trim();
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
