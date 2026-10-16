pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Звуковые события: синглтон на ~20 звуков из ~/oberon/assets/sounds (*.oga).
// Метод play(name) — безопасный: имя звука без расширения, тихо уходит, если
// файла нет или звук выключен. Плеер: pw-play, иначе paplay (auto-detect).
Singleton {
    id: snd

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    readonly property bool enabled: Prefs.soundsEnabled
    readonly property string dir: Quickshell.env("HOME") + "/oberon/assets/sounds"

    // Плеер выбирается один раз: pw-play → paplay; нет плеера — звука нет.
    property string player: ""   // "pw-play" | "paplay" | "" (нет плеера)
    readonly property string playerArgs: ""   // запас на будущее

    readonly property var knownSounds: [
        "alarm", "alert", "battery-critical", "battery-low", "beacon",
        "brightness", "bt-in", "bt-out", "camera-off", "camera-on",
        "caps-off", "caps-on", "capture", "charged", "chime", "glint",
        "halo", "mic-off", "mic-on", "orbit", "power-in", "power-out",
        "pulse", "reminder", "tap", "usb-in", "usb-out", "volume"
    ]

    Component.onCompleted: detectPlayer()
    onEnabledChanged: { /* только чтение в play(); ничего не перезапускаем */ }

    Process {
        id: detectProc
        command: ["sh", "-c",
            "command -v pw-play && echo pw-play || { command -v paplay && echo paplay || true; }"]
        stdout: SplitParser { onRead: line => { const v = line.trim(); if (v) snd.player = v; } }
    }
    function detectPlayer() { detectProc.running = false; detectProc.running = true; }

    // Главное API: play("alert"), play("tap"), ... ничего не кидает при ошибках.
    function play(name) {
        if (!enabled || player.length === 0 || !name) return;
        const s = String(name);
        if (!/^[a-z0-9-]{1,64}$/.test(s)) return; // защита от инъекций в путь
        if (knownSounds.indexOf(s) === -1) return;
        const f = dir + "/" + s + ".oga";
        Quickshell.execDetached(["sh", "-c",
            "test -f " + shq(f) + " && " + shq(player) + " " + shq(f) + " >/dev/null 2>&1 &"]);
    }

    // По желанию: настроенный в будущем маппинг событий на имена звуков.
    function notify(kind) {
        const map = {
            "notif": "alert", "notif-critical": "alarm", "volume": "volume",
            "brightness": "brightness", "battery-low": "battery-low",
            "battery-critical": "battery-critical", "charged": "charged",
            "camera-on": "camera-on", "camera-off": "camera-off",
            "mic-on": "mic-on", "mic-off": "mic-off", "bt-in": "bt-in",
            "bt-out": "bt-out", "usb-in": "usb-in", "usb-out": "usb-out",
            "caps-on": "caps-on", "caps-off": "caps-off", "capture": "capture",
            "power-in": "power-in", "power-out": "power-out"
        };
        play(map[kind] || "alert");
    }
}
