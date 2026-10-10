pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System controls + data: Wi-Fi, Bluetooth, brightness (DDC/CI), audio devices,
// DND, power.
Singleton {
    id: s

    // ── Wi-Fi ──────────────────────────────────────────────────────────
    property bool wifiEnabled: false
    property var wifiNetworks: []
    Process {
        id: wifiStateProc
        command: ["nmcli", "-t", "-f", "WIFI", "general"]
        running: true
        stdout: SplitParser { onRead: line => s.wifiEnabled = line.trim() === "enabled" }
    }
    Process {
        id: wifiListProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(":");
                const ssid = p[0];
                const sig = parseInt(p[1]);
                const sec = p.slice(2).join(":");
                if (ssid && ssid.length > 0) {
                    const arr = s.wifiNetworks.slice();
                    arr.push({ ssid: ssid, signal: isNaN(sig) ? 0 : sig, security: sec });
                    s.wifiNetworks = arr;
                }
            }
        }
    }
    function refreshWifi() { s.wifiNetworks = []; wifiListProc.running = false; wifiListProc.running = true; }
    function toggleWifi() {
        const next = !s.wifiEnabled;
        Quickshell.execDetached(["nmcli", "radio", "wifi", next ? "on" : "off"]);
        s.wifiEnabled = next;
    }
    function connectWifi(ssid, password) {
        if (password && password.length > 0)
            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid, "password", password]);
        else
            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid]);
    }

    // ── Живой статус соединений (большие карточки панели) ─────────────
    property string activeSsid: ""
    property var btConnected: []   // имена подключённых устройств

    Process {
        id: linkProc
        command: ["sh", "-c",
            "echo \"WIFI $(nmcli -t -f WIFI general 2>/dev/null)\"; " +
            "printf 'SSID %s\\n' \"$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}')\"; " +
            "C=$(timeout 4 bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [0-9A-Fa-f:]* //' | paste -sd'|' -); echo \"BTCONN ${C:-}\"; " +
            "B=$(timeout 4 bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}'); echo \"BT ${B:-no}\""]
        stdout: SplitParser {
            onRead: line => s._linkLine(line)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            linkProc.running = false;
            linkProc.running = true;
        }
    }

    function _linkLine(line) {
        if (line.startsWith("WIFI "))
            s.wifiEnabled = line.slice(5).trim() === "enabled";
        else if (line.startsWith("SSID "))
            s.activeSsid = line.slice(5).trim();
        else if (line.startsWith("BTCONN ")) {
            const v = line.slice(7).trim();
            s.btConnected = v === "" ? [] : v.split("|");
        } else if (line.startsWith("BT "))
            s.btEnabled = line.slice(3).trim() === "yes";
    }

    // ── Bluetooth ──────────────────────────────────────────────────────
    property bool btEnabled: false
    property var btDevices: []
    Process {
        id: btStateProc
        command: ["timeout", "5", "bluetoothctl", "show"]
        running: true
        stdout: SplitParser { onRead: line => { if (line.indexOf("Powered:") !== -1) s.btEnabled = line.indexOf("yes") !== -1; } }
    }
    Process {
        id: btListProc
        command: ["timeout", "6", "bluetoothctl", "devices"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.*)$/);
                if (m) {
                    const arr = s.btDevices.slice();
                    arr.push({ mac: m[1], name: m[2] });
                    s.btDevices = arr;
                }
            }
        }
    }
    function refreshBt() { s.btDevices = []; btListProc.running = false; btListProc.running = true; }
    Process {
        id: btScanProc
        command: ["bluetoothctl", "--timeout", "12", "scan", "on"]
        stdout: SplitParser {
            onRead: line => {
                const clean = line.replace(/\x1b\[[0-9;]*m/g, "");
                if (clean.indexOf("[NEW]") === -1) return;
                const m = clean.match(/Device\s+([0-9A-Fa-f:]+)\s+(.*)$/);
                if (m) {
                    const arr = s.btDevices.slice();
                    for (const d of arr) if (d.mac === m[1]) return;
                    arr.push({ mac: m[1], name: m[2] });
                    s.btDevices = arr;
                }
            }
        }
        onExited: s.refreshBt()
    }
    function startBtScan() { s.btDevices = []; btScanProc.running = false; btScanProc.running = true; }
    function toggleBt() {
        const next = !s.btEnabled;
        Quickshell.execDetached(["bluetoothctl", "power", next ? "on" : "off"]);
        s.btEnabled = next;
    }

    // ── Brightness (DDC/CI, external monitor) ──────────────────────────
    property int brightness: 100
    property int brightnessMax: 100
    Process {
        id: brProc
        command: ["ddcutil", "getvcp", "10", "--brief"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(/\s+/);   // VCP 10 C <cur> <max>
                if (p.length >= 5 && p[0] === "VCP") {
                    const cur = parseInt(p[3]), mx = parseInt(p[4]);
                    if (!isNaN(cur)) s.brightness = cur;
                    if (!isNaN(mx) && mx > 0) s.brightnessMax = mx;
                }
            }
        }
    }
    function refreshBrightness() { brProc.running = false; brProc.running = true; }
    function setBrightnessPct(pct) {
        const v = Math.max(0, Math.min(100, Math.round(pct)));
        s.brightness = v;
        Quickshell.execDetached(["ddcutil", "setvcp", "10", String(v)]);
    }
    readonly property real brightnessFraction: brightnessMax > 0 ? brightness / brightnessMax : 0

    // ── Audio devices (PipeWire) ───────────────────────────────────────
    function setDefaultAudio(nodeId) { Quickshell.execDetached(["wpctl", "set-default", String(nodeId)]); }
    function setStreamVolume(nodeId, v) {
        Quickshell.execDetached(["wpctl", "set-volume", String(nodeId), Math.round(Math.max(0, Math.min(1, v)) * 100) + "%"]);
    }

    // ── Do Not Disturb ─────────────────────────────────────────────────
    property bool dnd: false

    // ── Power ──────────────────────────────────────────────────────────
    function suspend()  { Quickshell.execDetached(["systemctl", "suspend"]); }
    function reboot()   { Quickshell.execDetached(["systemctl", "reboot"]); }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function logout()   { Quickshell.execDetached(["umbriel", "msg", "session-quit:skip-confirmation"]); }
}
