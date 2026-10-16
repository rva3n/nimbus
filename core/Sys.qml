pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

// System controls + data: Wi-Fi, Bluetooth, brightness (DDC/CI), audio devices,
// power.
Singleton {
    id: s

    // ── Wi-Fi ──────────────────────────────────────────────────────────
    property bool wifiEnabled: Networking.wifiEnabled
    property int _wifiRefreshTick: 0
    property var wifiNetworks: {
        const refreshTick = s._wifiRefreshTick;
        if (!Networking.wifiEnabled)
            return [];
        const bySsid = new Map();
        for (const device of Networking.devices.values) {
            if (device.type !== DeviceType.Wifi)
                continue;
            for (const network of device.networks.values) {
                const ssid = String(network.name || "");
                if (ssid === "")
                    continue;
                const signal = Math.round(Math.max(0, Math.min(1, network.signalStrength)) * 100);
                const connected = !!network.connected;
                const security = network.security === WifiSecurityType.Open
                    ? "--" : WifiSecurityType.toString(network.security);
                const current = bySsid.get(ssid);
                if (!current) {
                    bySsid.set(ssid, { ssid: ssid, signal: signal, security: security,
                        connected: connected, network: network });
                    continue;
                }
                const wasConnected = current.connected;
                current.connected = wasConnected || connected;
                if (connected && !wasConnected) {
                    current.network = network;
                    current.security = security;
                } else if (!wasConnected && !connected && signal > current.signal) {
                    current.network = network;
                    current.security = security;
                }
                current.signal = Math.max(current.signal, signal);
            }
        }
        const result = Array.from(bySsid.values());
        result.sort((a, b) => Number(b.connected) - Number(a.connected)
            || b.signal - a.signal || a.ssid.localeCompare(b.ssid, "ru"));
        return result;
    }
    property string activeSsid: {
        if (!Networking.wifiEnabled)
            return "";
        for (const device of Networking.devices.values) {
            if (device.type !== DeviceType.Wifi)
                continue;
            for (const network of device.networks.values)
                if (network.connected)
                    return network.name;
        }
        return "";
    }

    // Тост об ошибке внешней команды (прямая реакция на действие пользователя,
    // поэтому не глушится DND — как и OSD).
    function _fail(msg) {
        Notif.push({ appName: "Oberon", summary: "Ошибка", body: msg }, Umbriel.activeOutput);
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            if (Networking.wifiEnabled)
                s.refreshWifi();
            else
                s._stopWifiScan();
        }
    }

    Timer {
        id: wifiScanTimer
        interval: 12000
        onTriggered: s._stopWifiScan()
    }

    function _stopWifiScan() {
        wifiScanTimer.stop();
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                device.scannerEnabled = false;
        }
        s._wifiRefreshTick++;
    }

    function refreshWifi() {
        s._wifiRefreshTick++;
        if (!Networking.wifiEnabled)
            return;
        for (const device of Networking.devices.values) {
            if (device.type !== DeviceType.Wifi)
                continue;
            if (device.scannerEnabled)
                device.scannerEnabled = false;
            device.scannerEnabled = true;
        }
        wifiScanTimer.restart();
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function _findWifiNetwork(ssid) {
        let best = null;
        let bestSignal = -1;
        for (const device of Networking.devices.values) {
            if (device.type !== DeviceType.Wifi)
                continue;
            for (const network of device.networks.values) {
                if (network.name !== ssid)
                    continue;
                if (network.connected)
                    return network;
                if (network.signalStrength > bestSignal) {
                    best = network;
                    bestSignal = network.signalStrength;
                }
            }
        }
        return best;
    }

    property var _wifiConnectTarget: null
    Connections {
        target: s._wifiConnectTarget
        function onConnectedChanged() {
            if (s._wifiConnectTarget && s._wifiConnectTarget.connected)
                s._wifiConnectTarget = null;
        }
        function onStateChanged() {
            if (s._wifiConnectTarget && s._wifiConnectTarget.connected)
                s._wifiConnectTarget = null;
        }
        function onConnectionFailed(reason) {
            const target = s._wifiConnectTarget;
            if (!target)
                return;
            s._fail("Не удалось подключиться к «" + target.name + "»: " + ConnectionFailReason.toString(reason));
            s._wifiConnectTarget = null;
        }
    }

    Process {
        id: wifiConnectProc
        property string targetSsid: ""
        property string pendingPassword: ""
        property var queued: null         // { ssid, password } следующего запроса подключения
        stdinEnabled: true
        onStarted: {
            if (wifiConnectProc.pendingPassword !== "") {
                wifiConnectProc.write(wifiConnectProc.pendingPassword + "\n");
                wifiConnectProc.pendingPassword = "";
            }
        }
        onExited: (code) => {
            if (code !== 0) s._fail("Не удалось подключиться к «" + targetSsid + "»");
            if (wifiConnectProc.queued) {
                const q = wifiConnectProc.queued;
                wifiConnectProc.queued = null;
                s._startConnect(q.ssid, q.password);
                return;
            }
            s.refreshWifi();
        }
    }

    function _startConnect(ssid, password) {
        const network = s._findWifiNetwork(ssid);
        const psk = password || "";
        if (network && (!psk || network.security === WifiSecurityType.WpaPsk
                || network.security === WifiSecurityType.Wpa2Psk
                || network.security === WifiSecurityType.Sae)) {
            s._wifiConnectTarget = network;
            if (psk)
                network.connectWithPsk(psk);
            else
                network.connect();
            if (network.connected)
                s._wifiConnectTarget = null;
            return;
        }

        // Fallback for security modes without a native PSK API. The secret stays
        // on stdin; it is never included in nmcli's argv.
        wifiConnectProc.targetSsid = ssid;
        wifiConnectProc.pendingPassword = psk;
        if (psk !== "") {
            wifiConnectProc.command = ["timeout", "30", "sh", "-c",
                "set -e; if ! nmcli connection modify id \"$1\" wifi-sec.key-mgmt wpa-psk >/dev/null 2>&1; then " +
                "nmcli connection add type wifi ifname '*' con-name \"$1\" ssid \"$1\" wifi-sec.key-mgmt wpa-psk >/dev/null; fi; " +
                "IFS= read -r password || exit 1; " +
                "printf '802-11-wireless-security.psk:%s\\n' \"$password\" | nmcli connection up id \"$1\" passwd-file /dev/stdin",
                "oberon-wifi", ssid];
        } else {
            wifiConnectProc.command = ["timeout", "30", "nmcli", "device", "wifi", "connect", ssid];
        }
        wifiConnectProc.running = true;
    }

    function connectWifi(ssid, password) {
        if (wifiConnectProc.running) {
            wifiConnectProc.queued = { ssid: ssid, password: password };
            return;
        }
        s._startConnect(ssid, password);
    }

    // ── Bluetooth ──────────────────────────────────────────────────────
    property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property bool btDiscovering: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
    property int _btRefreshTick: 0
    property var btDevices: {
        const refreshTick = s._btRefreshTick;
        const seen = new Set();
        const result = [];
        for (const adapter of Bluetooth.adapters.values) {
            for (const device of adapter.devices.values) {
                const mac = String(device.address || "");
                const key = device.dbusPath || mac;
                if (seen.has(key))
                    continue;
                seen.add(key);
                result.push({
                    mac: mac,
                    name: String(device.name || device.deviceName || mac),
                    connected: !!device.connected,
                    paired: !!device.paired,
                    pairing: !!device.pairing,
                    device: device
                });
            }
        }
        result.sort((a, b) => Number(b.connected) - Number(a.connected)
            || Number(b.paired) - Number(a.paired) || a.name.localeCompare(b.name, "ru"));
        return result;
    }
    property var btConnected: s.btDevices.filter(device => device.connected).map(device => device.name)
    property var _scanAdapter: null
    property var _btEnableAdapter: null
    property bool _btEnablePending: false
    property bool _btEnableRetried: false
    property bool _btEnableWaited: false

    function refreshBt() { s._btRefreshTick++; }

    function _finishBtEnable() {
        const adapter = s._btEnableAdapter;
        if (s._btEnablePending && adapter && adapter.enabled
                && adapter.state === BluetoothAdapterState.Enabled) {
            s._btEnablePending = false;
            s._btEnableRetried = false;
            s._btEnableWaited = false;
            btEnableTimer.stop();
            s._btEnableAdapter = null;
        }
    }

    function _failBtEnable() {
        s._btEnablePending = false;
        s._btEnableRetried = false;
        s._btEnableWaited = false;
        btEnableTimer.stop();
        s._btEnableAdapter = null;
        s._fail("Не удалось включить Bluetooth");
    }

    Connections {
        target: s._btEnableAdapter
        function onEnabledChanged() { s._finishBtEnable(); }
        function onStateChanged() { s._finishBtEnable(); }
    }

    Process {
        id: btRfkillProc
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: (code) => {
            if (!s._btEnablePending)
                return;
            if (code !== 0 || !s._btEnableAdapter) {
                s._failBtEnable();
                return;
            }
            // Retry the native setter after clearing a soft block.
            s._btEnableAdapter.enabled = false;
            s._btEnableAdapter.enabled = true;
            s._btEnableWaited = false;
            btEnableTimer.restart();
        }
    }

    Timer {
        id: btEnableTimer
        interval: 2500
        onTriggered: {
            s._finishBtEnable();
            if (!s._btEnablePending)
                return;
            if (s._btEnableAdapter
                    && s._btEnableAdapter.state === BluetoothAdapterState.Enabling
                    && !s._btEnableWaited) {
                s._btEnableWaited = true;
                btEnableTimer.restart();
            } else if (!s._btEnableRetried) {
                s._btEnableRetried = true;
                btRfkillProc.running = true;
            } else {
                s._failBtEnable();
            }
        }
    }

    function startBtScan() {
        const adapter = Bluetooth.defaultAdapter;
        s.refreshBt();
        if (!adapter || !adapter.enabled)
            return;
        if (adapter.discovering) {
            if (s._scanAdapter === adapter)
                btScanTimer.restart();
            return;
        }
        s._scanAdapter = adapter;
        adapter.discovering = true;
        btScanTimer.restart();
    }

    Timer {
        id: btScanTimer
        interval: 12000
        onTriggered: {
            if (s._scanAdapter && s._scanAdapter.discovering)
                s._scanAdapter.discovering = false;
            s._scanAdapter = null;
        }
    }

    function toggleBt() {
        const adapter = Bluetooth.defaultAdapter;
        if (!adapter)
            return;

        const next = s._btEnablePending && s._btEnableAdapter === adapter
            ? false : !adapter.enabled;
        if (next) {
            s._btEnableAdapter = adapter;
            s._btEnablePending = true;
            s._btEnableRetried = false;
            s._btEnableWaited = false;
            adapter.enabled = true;
            s._finishBtEnable();
            if (s._btEnablePending)
                btEnableTimer.restart();
        } else {
            s._btEnablePending = false;
            s._btEnableRetried = false;
            s._btEnableWaited = false;
            btEnableTimer.stop();
            s._btEnableAdapter = null;
            adapter.enabled = false;
            btScanTimer.stop();
            s._scanAdapter = null;
        }
        s.refreshBt();
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
