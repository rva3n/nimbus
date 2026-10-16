pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Напоминания: ~/.local/state/oberon/reminders.json — [{ id, ts, text, fired }].
// Раз в 30с проверяются наступившие: пришедшее время шлётся тостом через Notif
// (как «Tаймер завершён» в shell.qml — не молчит под DND) и помечается fired.
// Файл — единственный источник правды: пишем атомарно (tmp + mv), читаем на
// старте и перечитываем каждые 60с. Своя запись в полёте блокирует перечитку,
// чтобы внешний дамп не затёр свежее состояние (без потери данных).
Singleton {
    id: rem

    // по возрастанию ts; mutation — только через присвоение нового массива
    property var items: []
    readonly property string path: Quickshell.env("HOME") + "/.local/state/oberon/reminders.json"
    // отмеченные дни для ui/MonthView (marked): ключи "г-м-д", месяц 0-based
    readonly property var marks: {
        const out = {};
        for (const it of rem.items) {
            if (!it || !isFinite(Number(it.ts))) continue;
            const d = new Date(it.ts);
            out[d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate()] = true;
        }
        return out;
    }

    // ── упаковка/разбор ───────────────────────────────────────────────
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    function sanitize(list) {
        if (!Array.isArray(list)) return [];
        const out = [];
        for (const it of list) {
            if (!it || typeof it !== "object") continue;
            const ts = Number(it.ts);
            const text = String(it.text || "");
            if (!isFinite(ts) || text === "") continue;
            out.push({ "id": String(it.id || rem._nextId()), "ts": ts, "text": text, "fired": it.fired === true });
        }
        return out;
    }

    function parseLine(line) {
        try {
            const j = JSON.parse(line);
            const arr = rem.sanitize(j);
            // присваиваем только если что-то реально изменилось — иначе лишний
            // пересбор подписчиков (Repeater) на каждой перечитке
            if (JSON.stringify(arr) !== JSON.stringify(rem.items)) rem.items = arr;
        } catch (e) {}
    }

    // ── чтение ────────────────────────────────────────────────────────
    Process {
        id: readProc

        command: ["sh", "-c", "cat " + rem.shq(rem.path) + " 2>/dev/null"]

        stdout: SplitParser {
            onRead: line => rem.parseLine(line)
        }

        onExited: rem._afterLoad()
    }

    function load() {
        readProc.running = false;
        readProc.running = true;
    }

    function _afterLoad() {
        // принятая перечитка сразу просеивается через проверку «наступило»
        rem.checkDue();
    }

    // периодическая перечитка (внешние правки файла, другие инстансы)
    Timer {
        id: reloadTimer

        interval: 60000
        repeat: true
        running: true
        onTriggered: if (!rem.saving) rem.load()
    }

    // ── запись: tmp + rename, один процесс, очередь одним флагом ─────
    property bool saving: false
    property bool _dirty: false

    Process {
        id: writeProc

        onExited: {
            rem.saving = false;
            if (rem._dirty) {
                rem._dirty = false;
                rem.save();
            }
        }
    }

    // дебаунс частых add/remove/update: правки подряд пишутся одной записью
    function scheduleSave() { saveTimer.restart(); }

    function save() {
        if (rem.saving) {
            rem._dirty = true;
            return ;
        }
        rem.saving = true;
        const j = JSON.stringify(rem.items);
        const dir = Quickshell.env("HOME") + "/.local/state/oberon";
        writeProc.command = ["sh", "-c",
            "mkdir -p " + rem.shq(dir) + "; printf %s " + rem.shq(j) + " > " + rem.shq(rem.path + ".tmp") + "; mv -f " + rem.shq(rem.path + ".tmp") + " " + rem.shq(rem.path)];
        writeProc.running = false;
        writeProc.running = true;
    }

    Timer {
        id: saveTimer

        interval: 300
        onTriggered: rem.save()
    }

    // ── публичный API ─────────────────────────────────────────────────
    property int _serial: 0

    function _nextId() {
        return String(Date.now()) + "-" + (++rem._serial);
    }

    function add(text, ts) {
        const t = String(text || "").trim();
        if (t === "" || !isFinite(ts)) return "";
        const arr = rem.items.slice();
        arr.push({ "id": rem._nextId(), "ts": Math.round(ts), "text": t, "fired": false });
        arr.sort((a, b) => a.ts - b.ts);
        rem.items = arr;
        rem.scheduleSave();
        rem.checkDue();
        return arr[arr.length - 1].id;
    }

    function remove(id) {
        const arr = rem.items.filter(it => it.id !== id);
        if (arr.length === rem.items.length) return ;
        rem.items = arr;
        rem.scheduleSave();
    }

    function update(id, patch) {
        if (!patch) return ;
        const arr = rem.items.slice();
        let changed = false;
        for (const it of arr) {
            if (it.id !== id) continue;
            const merged = Object.assign({}, it, patch);
            if (JSON.stringify(merged) === JSON.stringify(it)) continue;
            arr[arr.indexOf(it)] = merged;
            changed = true;
        }
        if (!changed) return ;
        rem.items = arr;
        rem.scheduleSave();
    }

    // напоминания выбранного дня (для карточки в CalendarPage), по времени
    function day(y, m, d) {
        const lo = new Date(y, m, d).getTime();
        const hi = lo + 86400000 - 1;
        return rem.items.filter(it => it.ts >= lo && it.ts <= hi);
    }

    // «12 окт, 14:35» — тело тоста
    function fmtWhen(ts) {
        const mon = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
        const d = new Date(ts);
        const p = n => (n < 10 ? "0" : "") + n;
        return d.getDate() + " " + mon[d.getMonth()] + ", " + p(d.getHours()) + ":" + p(d.getMinutes());
    }

    // ── проверка наступивших ─────────────────────────────────────────
    // старше 12ч при старте шелла — помечаем сработавшим без тоста, чтобы
    // не получить в лицо залп вчерашних напоминаний при включении
    function checkDue() {
        const now = Date.now();
        let changed = false;
        const arr = rem.items.slice();
        for (let i = 0; i < arr.length; i++) {
            const it = arr[i];
            if (!it || it.fired || it.ts > now) continue;
            if (now - it.ts <= 43200000)
                Notif.push({ "appName": "Напоминание", "summary": it.text, "body": rem.fmtWhen(it.ts) });
            arr[i] = Object.assign({}, it, { "fired": true });
            changed = true;
        }
        // новые массивы всегда — иначе подписчики не узнают о замене
        if (changed) {
            rem.items = arr;
            rem.scheduleSave();
        }
    }

    Timer {
        id: dueTimer

        interval: 30000
        repeat: true
        running: true
        onTriggered: rem.checkDue()
    }

    Component.onCompleted: load()
}
