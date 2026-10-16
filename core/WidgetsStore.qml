pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Состояние desktop-виджетов: ~/.local/state/oberon/widgets.json —
// { "enabled": { id: bool }, "pos": { id: { x, y } } }.
// Экран рисует layers: компоненты/WidgetLayer.qml читает и пишет через этот
// синглтон (тумблеры виджетов — из страницы настроек или через toggle).
// Файл — единственный источник правды: атомарная запись (tmp + mv), дебаунс,
// перечитка раз в 60с. Своя запись в полёте блокирует перечитку, чтобы внешний
// дамп не затёр свежее состояние (по образцу core/Reminders.qml, без потери).
Singleton {
    id: store

    readonly property bool ready: store._loaded
    property bool _loaded: false

    // ── состояние: var-объекты пересоздаются целиком, чтобы биндинги видели смены ──
    property var enabledMap: ({})
    property var pos: ({})

    // известные виджеты и их анатомия по умолчанию (dp, без uiScale).
    // col: "tr" — колонка правого верхнего угла, "lb" — левого нижнего (подальше
    // от острова вверху по центру и медиа-пилюли в левом верхнем углу).
    // off — готовый отступ от угла вдоль колонки (запас + высоты выше).
    readonly property var defs: ({
        "clock": { "file": "ClockWidget.qml", "col": "tr", "w": 236, "h": 150, "off": 84 },
        "weather": { "file": "WeatherWidget.qml", "col": "tr", "w": 236, "h": 140, "off": 84 + 150 + 28 },
        "visualizer": { "file": "VisualizerWidget.qml", "col": "tr", "w": 296, "h": 96, "off": 84 + 150 + 28 + 140 + 28 },
        "system": { "file": "SystemWidget.qml", "col": "lb", "w": 236, "h": 104, "off": 72 },
        "media": { "file": "MediaWidget.qml", "col": "lb", "w": 296, "h": 96, "off": 72 + 104 + 28 }
    })

    // дефолтная позиция на экране экрана scrW×scrH при интерфейсном масштабе k
    function defPos(id, scrW, scrH, k) {
        const d = store.defs[id];
        if (!d)
            return { "x": 0, "y": 0 };
        const w = Math.round(d.w * k);
        const h = Math.round(d.h * k);
        const m = Math.round(72 * k);
        const off = Math.round(d.off * k);
        if (d.col === "tr")
            return { "x": Math.round(scrW - m - w), "y": off };
        return { "x": m, "y": Math.round(scrH - m - h - off) };
    }

    // ── публичный API ─────────────────────────────────────────────────
    function isEnabled(id) {
        const e = store.enabledMap[id];
        return e === undefined ? true : Boolean(e);
    }

    function setEnabled(id, on) {
        if (!store.defs[id])
            return ;
        const next = {};
        for (const k in store.enabledMap)
            next[k] = Boolean(store.enabledMap[k]);
        next[id] = Boolean(on);
        store.enabledMap = next;
        store.scheduleSave();
    }

    function toggle(id) {
        store.setEnabled(id, !store.isEnabled(id));
        return store.isEnabled(id);
    }

    // позиция из store или дефолт (xy считается в WidgetLayer, у store нет экрана)
    function posOf(id, defX, defY) {
        const p = store.pos[id];
        return p && isFinite(Number(p.x)) && isFinite(Number(p.y)) ? { "x": Number(p.x), "y": Number(p.y) } : { "x": defX, "y": defY };
    }

    function move(id, x, y) {
        if (!isFinite(Number(x)) || !isFinite(Number(y)))
            return ;
        const built = {};
        for (const k in store.pos)
            built[k] = { "x": Number(store.pos[k].x), "y": Number(store.pos[k].y) };
        built[id] = { "x": Math.round(Number(x)), "y": Math.round(Number(y)) };
        store.pos = built;
        store.scheduleSave();
    }

    // ── чтение: cat + разбор, перечитка по таймеру ─────────────────────
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    readonly property string path: Quickshell.env("HOME") + "/.local/state/oberon/widgets.json"

    function sanitize(j) {
        const out = { "enabled": {}, "pos": {} };
        if (!j || typeof j !== "object")
            return out;
        const en = j.enabled;
        const ps = j.pos;
        for (const id in store.defs) {
            if (en && en[id] !== undefined)
                out.enabled[id] = Boolean(en[id]);
            if (ps && ps[id] && isFinite(Number(ps[id].x)) && isFinite(Number(ps[id].y)))
                out.pos[id] = { "x": Math.round(Number(ps[id].x)), "y": Math.round(Number(ps[id].y)) };
        }
        return out;
    }

    function parseLine(line) {
        try {
            const s = store.sanitize(JSON.parse(line));
            // присваиваем только при реальном изменении — иначе лишний пересбор
            // подписчиков на каждой перечитке
            const applied = JSON.stringify(store.enabledMap) !== JSON.stringify(s.enabled) || JSON.stringify(store.pos) !== JSON.stringify(s.pos);
            if (applied) {
                store.enabledMap = s.enabled;
                store.pos = s.pos;
            }
        } catch (e) {}
        store._loaded = true;
    }

    function load() {
        readProc.running = false;
        readProc.running = true;
    }

    Process {
        id: readProc

        command: ["sh", "-c", "cat " + store.shq(store.path) + " 2>/dev/null"]

        stdout: SplitParser {
            onRead: line => store.parseLine(line)
        }

        onExited: store._loaded = true  // пустой/отсутствующий файл — тоже готово
    }

    Timer {
        id: reloadTimer

        interval: 60000
        repeat: true
        running: true
        onTriggered: if (!store.saving) store.load()
    }

    // ── запись: tmp + rename, один процесс, очередь через флаги ────────
    property bool saving: false
    property bool _dirty: false

    Process {
        id: writeProc

        onExited: {
            store.saving = false;
            if (store._dirty) {
                store._dirty = false;
                store.save();
            }
        }
    }

    function scheduleSave() { saveTimer.restart(); }

    function save() {
        if (store.saving) {
            store._dirty = true;
            return ;
        }
        store.saving = true;
        const j = JSON.stringify({ "enabled": store.enabledMap, "pos": store.pos });
        const dir = Quickshell.env("HOME") + "/.local/state/oberon";
        writeProc.command = ["sh", "-c",
            "mkdir -p " + store.shq(dir) + "; printf %s " + store.shq(j) + " > " + store.shq(store.path + ".tmp") + "; mv -f " + store.shq(store.path + ".tmp") + " " + store.shq(store.path)];
        writeProc.running = false;
        writeProc.running = true;
    }

    Timer {
        id: saveTimer

        interval: 300
        onTriggered: store.save()
    }

    Component.onCompleted: load()
}
