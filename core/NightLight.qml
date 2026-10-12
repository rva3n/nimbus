pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ночной свет: ровно один управляемый Process с gammastep.
// Режимы:
//   manual   — gammastep -O <temp> (постоянная температура)
//   schedule — грелка включена только внутри окна nightLightFrom..nightLightTo
//   sunset   — gammastep -l lat:lon -t 6500:<temp> (сам следит за закатом;
//              без координат — фолбэк на manual)
// Изменение temp/mode/enabled → рестарт/останов того же Process (без гонок и
// процессов-сирот). При остановке gammastep на SIGTERM сам снимает тёплоту.
Singleton {
    id: nl

    // ── состояние ─────────────────────────────────────────────────────
    readonly property bool active: gsProc.running
    property bool scheduleActive: false  // для mode schedule: сейчас в окне?
    readonly property bool prefsOn: Prefs.nightLightEnabled

    readonly property int temp: {
        const n = Math.round(Number(Prefs.nightLightTemp));
        if (isNaN(n) || n <= 0) return 4500;
        return Math.min(10000, Math.max(1000, n));
    }
    readonly property string mode: {
        const v = String(Prefs.nightLightMode);
        return (v === "schedule" || v === "sunset") ? v : "manual";
    }
    readonly property bool geoOk: Prefs.weatherLat !== 0 || Prefs.weatherLon !== 0

    // ── разбор времени "HH:MM" → минуты с полуночи (или дефолт) ───────
    function parseHm(s, dflt) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(s));
        if (!m) return dflt;
        const h = parseInt(m[1], 10), mi = parseInt(m[2], 10);
        if (h < 0 || h > 23 || mi < 0 || mi > 59) return dflt;
        return h * 60 + mi;
    }
    readonly property int fromMin: parseHm(Prefs.nightLightFrom, 22 * 60) // 22:00
    readonly property int toMin: parseHm(Prefs.nightLightTo, 7 * 60)      // 07:00

    // окно может переходить через полночь (22:00 → 07:00)
    function inScheduleWindow(nowMin) {
        if (fromMin === toMin) return false;
        return fromMin > toMin ? (nowMin >= fromMin || nowMin < toMin)
                               : (nowMin >= fromMin && nowMin < toMin);
    }
    function currentScheduleActive() {
        const d = new Date();
        return inScheduleWindow(d.getHours() * 60 + d.getMinutes());
    }

    // ── процесс грелки ────────────────────────────────────────────────
    Process {
        id: gsProc
        command: []
    }
    // страховочный сброс (не должен понадобиться, но пусть будет):
    // короткоживущий нейтральный прогон, гарантированно завершается сам.
    Process {
        id: gsReset
        command: ["timeout", "2", "gammastep", "-O", "6500"]
    }

    function start() {
        let cmd;
        if (mode === "schedule") {
            // Обычный (не one-shot) режим: держим температуру, окном управляет таймер.
            cmd = ["gammastep", "-O", String(temp)];
        } else if (mode === "sunset" && geoOk) {
            cmd = ["gammastep", "-l",
                   Number(Prefs.weatherLat).toFixed(4) + ":" + Number(Prefs.weatherLon).toFixed(4),
                   "-t", "6500:" + temp];
        } else {
            // sunset без координат → фолбэк на manual
            cmd = ["gammastep", "-O", String(temp)];
        }
        // рестарт: false→true терминирует прежнего ребёнка (ровно один инстанс)
        gsProc.command = cmd;
        gsProc.running = false;
        gsProc.running = true;
    }

    function stopAll() {
        gsProc.running = false;
        gsReset.running = false;
        gsReset.running = true; // добить нейтральным прогоном (2 c, сам выйдет)
    }
    function hardStop() {
        scheduleActive = false;
        stopAll();
    }

    // ── реакция на префы ──────────────────────────────────────────────
    onPrefsOnChanged: sync()
    onTempChanged: sync()
    onModeChanged: sync()
    onGeoOkChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        if (!Prefs.ready) return;
        if (!prefsOn) {
            schedTimer.running = false;
            scheduleActive = false;
            if (active) hardStop();
            return;
        }
        if (mode === "schedule") {
            schedTimer.running = true;
            applySchedule();
        } else {
            schedTimer.running = false;
            scheduleActive = false;
            start(); // рестарт того же Process — свежий temp/режим, без сирот
        }
    }

    function applySchedule() {
        const now = currentScheduleActive();
        scheduleActive = now;
        if (now && !active) start();        // вошли в окно (или рестарт после смены temp)
        else if (!now && active) hardStop(); // вышли из окна — снять теплоту
    }

    Timer { id: schedTimer; interval: 60000; repeat: true; onTriggered: nl.applySchedule() }
}
