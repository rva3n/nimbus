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
    readonly property bool timerDone: !c.running && c.remaining === 0 && c.totalSeconds > 0

    signal finished()

    // Завести таймер на sec секунд (0 — просто сброс).
    function start(sec) {
        const s = Math.max(0, Math.round(sec));
        c.running = false;
        c.totalSeconds = s;
        c.remaining = s;
        if (s > 0)
            c.running = true;
    }
    function pause() { c.running = false }
    function resume() { if (c.remaining > 0) c.running = true }
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
    }
    // Продлить на m минут; в простое выставляет время, не запуская.
    function addMin(m) {
        const d = Math.round(m * 60);
        if (d === 0)
            return;
        c.remaining = Math.max(0, c.remaining + d);
        if (c.remaining > c.totalSeconds)
            c.totalSeconds = c.remaining;
    }

    Timer {
        interval: 1000
        repeat: true
        running: c.running
        onTriggered: {
            c.remaining = Math.max(0, c.remaining - 1);
            if (c.remaining === 0) {
                c.running = false;
                c.finished();
            }
        }
    }

    // ── Секундомер ─────────────────────────────────────────────────────
    property bool swRunning: false
    property real swElapsed: 0     // секунды, с десятыми
    property var laps: []          // накопленное время каждого круга, сек

    // 100 мс — чтобы десятая доля в mm:ss.d реально тикала.
    Timer {
        interval: 100
        repeat: true
        running: c.swRunning
        onTriggered: c.swTick()
    }

    function swTick() { if (c.swRunning) c.swElapsed += 0.1 }
    function swStart() { c.swRunning = true }
    function swPause() { c.swRunning = false }
    function swToggle() { c.swRunning = !c.swRunning }
    function swReset() {
        c.swRunning = false;
        c.swElapsed = 0;
        c.laps = [];
    }
    // Новый массив — чтобы Repeater/ListView реагировали на добавление.
    function addLap() {
        if (c.swElapsed <= 0)
            return;
        const arr = c.laps.slice();
        arr.push(c.swElapsed);
        c.laps = arr;
    }
}
