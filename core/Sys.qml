pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System controls + data: Wi-Fi, Bluetooth, brightness (DDC/CI), audio devices,
// power.
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

    // Тост об ошибке внешней команды (прямая реакция на действие пользователя,
    // поэтому не глушится DND — как и OSD).
    function _fail(msg) { Notif.push({ appName: "Nimbus", summary: "Ошибка", body: msg }); }
    // Мгновенно перечитать живой статус, не дожидаясь 5-секундного таймера.
    function _refreshLink() { linkProc.running = false; linkProc.running = true; }

    Process {
        id: wifiToggleProc
        property bool queued: false       // новая цель, пока предыдущая команда ещё выполняется
        property bool queuedValue: false
        onExited: (code) => {
            if (code !== 0) s._fail("Не удалось переключить Wi-Fi");
            if (wifiToggleProc.queued) {  // без убийства: просто догоняем последней целью
                wifiToggleProc.queued = false;
                wifiToggleProc.command = ["timeout", "8", "nmcli", "radio", "wifi", wifiToggleProc.queuedValue ? "on" : "off"];
                wifiToggleProc.running = true;
                return;
            }
            s._refreshLink();
        }
    }
    function toggleWifi() {
        const next = !s.wifiEnabled;
        s.wifiEnabled = next;
        if (wifiToggleProc.running) { wifiToggleProc.queued = true; wifiToggleProc.queuedValue = next; return; }
        wifiToggleProc.command = ["timeout", "8", "nmcli", "radio", "wifi", next ? "on" : "off"];
        wifiToggleProc.running = true;
    }
    Process {
        id: wifiConnectProc
        property string targetSsid: ""
        property var queued: null         // { ssid, password } следующего запроса подключения
        onExited: (code) => {
            if (code !== 0) s._fail("Не удалось подключиться к «" + targetSsid + "»");
            if (wifiConnectProc.queued) {
                const q = wifiConnectProc.queued;
                wifiConnectProc.queued = null;
                s._startConnect(q.ssid, q.password);
                return;
            }
            s._refreshLink();
            s.refreshWifi();
        }
    }
    function _startConnect(ssid, password) {
        // timeout: зависший вызов прервётся и разблокирует очередь (код 124 → тост)
        const cmd = ["timeout", "30", "nmcli", "dev", "wifi", "connect", ssid];
        if (password && password.length > 0) cmd.push("password", password);
        wifiConnectProc.targetSsid = ssid;
        wifiConnectProc.command = cmd;
        wifiConnectProc.running = true;
    }
    function connectWifi(ssid, password) {
        if (wifiConnectProc.running) { wifiConnectProc.queued = { ssid: ssid, password: password }; return; }
        s._startConnect(ssid, password);
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
    Process {
        id: btToggleProc
        property bool queued: false
        property bool queuedValue: false
        onExited: (code) => {
            if (code !== 0) s._fail("Не удалось переключить Bluetooth");
            if (btToggleProc.queued) {
                btToggleProc.queued = false;
                btToggleProc.command = btPowerCommand(btToggleProc.queuedValue);
                btToggleProc.running = true;
                return;
            }
            s._refreshLink();
        }
    }
    function btPowerCommand(next) {
        // включение: сперва снять rfkill-soft-block (иначе bluez отвечает
        // org.bluez.Error.Blocked), повтор при org.bluez.Error.Busy
        if (next)
            return ["sh", "-c", "rfkill unblock bluetooth 2>/dev/null; timeout 8 bluetoothctl power on || { sleep 1; timeout 8 bluetoothctl power on; }"];
        return ["timeout", "8", "bluetoothctl", "power", "off"];
    }
    function toggleBt() {
        const next = !s.btEnabled;
        s.btEnabled = next;
        if (btToggleProc.running) { btToggleProc.queued = true; btToggleProc.queuedValue = next; return; }
        btToggleProc.command = btPowerCommand(next);
        btToggleProc.running = true;
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
    Process {
        id: brSetProc
        property int pending: -1          // последнее желаемое значение (key-repeat), -1 = нет
        onExited: (code) => {
            if (code !== 0) s._fail("Не удалось изменить яркость (ddcutil)");
            if (brSetProc.pending >= 0) { // пока писалось, яркость крутили дальше — догоняем последним значением
                const v = brSetProc.pending;
                brSetProc.pending = -1;
                brSetProc.command = ["timeout", "8", "ddcutil", "setvcp", "10", String(v)];
                brSetProc.running = true;
                return;
            }
            brVerifyTimer.restart();
        }
    }
    Timer { // сверка фактического значения после записи: s.brightness не должен врать
        id: brVerifyTimer
        interval: 800
        onTriggered: s.refreshBrightness()
    }
    function setBrightnessPct(pct) {
        const v = Math.max(0, Math.min(100, Math.round(pct)));
        s.brightness = v;
        if (brSetProc.running) { brSetProc.pending = v; return; }
        brSetProc.command = ["timeout", "8", "ddcutil", "setvcp", "10", String(v)];
        brSetProc.running = true;
    }
    readonly property real brightnessFraction: brightnessMax > 0 ? brightness / brightnessMax : 0

    // ── Audio devices (PipeWire) ───────────────────────────────────────
    function setDefaultAudio(nodeId) { Quickshell.execDetached(["wpctl", "set-default", String(nodeId)]); }
    function setStreamVolume(nodeId, v) {
        Quickshell.execDetached(["wpctl", "set-volume", String(nodeId), Math.round(Math.max(0, Math.min(1, v)) * 100) + "%"]);
    }

    // ── Power ──────────────────────────────────────────────────────────
    function suspend()  { Quickshell.execDetached(["systemctl", "suspend"]); }
    function reboot()   { Quickshell.execDetached(["systemctl", "reboot"]); }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function logout()   { Quickshell.execDetached(["umbriel", "msg", "session-quit:skip-confirmation"]); }
}
