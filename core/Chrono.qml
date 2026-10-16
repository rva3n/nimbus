pragma Singleton
import QtQuick
import Quickshell

// Таймер обратного отсчёта и секундомер для страницы «Таймеры».
// Состояние общее для шелла и живёт столько же, сколько сам процесс.
Singleton {
    id: c

    // ── Таймер обратного отсчёта ───────────────────────────────────────
    property int totalSeconds: 0   // изначально выставленное время
    property int remaining: 0      // сколько осталось
    property bool running: false
    property double countdownStartEpoch: 0
    property double countdownStartRemainingMs: 0
    readonly property bool timerDone: !c.running && c.remaining === 0 && c.totalSeconds > 0

    signal finished()

    // Завести таймер на sec секунд (0 — просто сброс).
    function start(sec) {
        const s = Math.max(0, Math.round(sec));
        c.running = false;
        c.totalSeconds = s;
        c.remaining = s;
        c.countdownStartRemainingMs = s * 1000;
        c.countdownStartEpoch = Date.now();
        if (s > 0)
            c.running = true;
    }
    function countdownMsNow() {
        if (!c.running)
            return c.countdownStartRemainingMs;
        return Math.max(0, c.countdownStartRemainingMs - (Date.now() - c.countdownStartEpoch));
    }
    function finishCountdown() {
        c.remaining = 0;
        c.countdownStartRemainingMs = 0;
        c.countdownStartEpoch = 0;
        c.running = false;
        c.finished();
    }
    function tickCountdown() {
        if (!c.running)
            return;
        const left = c.countdownMsNow();
        c.remaining = Math.ceil(left / 1000);
        if (left <= 0)
            c.finishCountdown();
    }
    function pause() {
        if (!c.running)
            return;
        const left = c.countdownMsNow();
        if (left <= 0) {
            c.finishCountdown();
            return;
        }
        c.countdownStartRemainingMs = left;
        c.countdownStartEpoch = 0;
        c.remaining = Math.ceil(left / 1000);
        c.running = false;
    }
    function resume() {
        if (c.remaining > 0) {
            c.countdownStartEpoch = Date.now();
            c.running = true;
        }
    }
    // Переключатель play/pause для отдельной кнопки.
    function toggle() {
        if (c.running)
            c.pause();
        else if (c.remaining > 0)
            c.resume();
        else if (c.totalSeconds > 0)
            c.start(c.totalSeconds);
    }
    // Вернуть к выставленному времени и остановить.
    function reset() {
        c.running = false;
        c.remaining = c.totalSeconds;
        c.countdownStartRemainingMs = c.totalSeconds * 1000;
        c.countdownStartEpoch = 0;
    }
    // Продлить на m минут; в простое выставляет время, не запуская.
    function addMin(m) {
        const d = Math.round(m * 60);
        if (d === 0)
            return;
        let left = c.countdownMsNow();
        if (c.running && left <= 0) {
            c.finishCountdown();
            left = 0;
        }
        const next = Math.max(0, left + d * 1000);
        c.countdownStartRemainingMs = next;
        c.countdownStartEpoch = c.running ? Date.now() : 0;
        c.remaining = Math.ceil(next / 1000);
        if (c.running && next <= 0)
            c.finishCountdown();
        if (c.remaining > c.totalSeconds)
            c.totalSeconds = c.remaining;
    }

    Timer {
        interval: 1000
        repeat: true
        running: c.running
        onTriggered: c.tickCountdown()
    }

    // ── Секундомер ─────────────────────────────────────────────────────
    property bool swRunning: false
    property real swElapsed: 0     // секунды, с десятыми
    property double swStartEpoch: 0
    property real swElapsedBeforeStart: 0
    property var laps: []          // накопленное время каждого круга, сек

    // 100 мс — чтобы десятая доля в mm:ss.d реально тикала.
    Timer {
        interval: 100
        repeat: true
        running: c.swRunning
        onTriggered: c.swTick()
    }

    function swElapsedNow() {
        return c.swRunning ? c.swElapsedBeforeStart + (Date.now() - c.swStartEpoch) / 1000 : c.swElapsed;
    }
    function swTick() {
        if (c.swRunning)
            c.swElapsed = c.swElapsedNow();
    }
    function swStart() {
        if (c.swRunning)
            return;
        c.swElapsedBeforeStart = c.swElapsed;
        c.swStartEpoch = Date.now();
        c.swRunning = true;
    }
    function swPause() {
        if (!c.swRunning)
            return;
        c.swElapsed = c.swElapsedNow();
        c.swElapsedBeforeStart = c.swElapsed;
        c.swStartEpoch = 0;
        c.swRunning = false;
    }
    function swToggle() { if (c.swRunning) c.swPause(); else c.swStart(); }
    function swReset() {
        c.swRunning = false;
        c.swElapsed = 0;
        c.swElapsedBeforeStart = 0;
        c.swStartEpoch = 0;
        c.laps = [];
    }
    // Новый массив — чтобы Repeater/ListView реагировали на добавление.
    function addLap() {
        const elapsed = c.swElapsedNow();
        if (elapsed <= 0)
            return;
        const arr = c.laps.slice();
        arr.push(elapsed);
        c.laps = arr;
        if (c.swRunning)
            c.swElapsed = elapsed;
    }
}
