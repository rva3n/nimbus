pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Состояние desktop-виджетов: ~/.local/state/oberon/widgets.json —
// { "enabled": { id: bool }, "pos": { id: { rx, ry } } }.
// Экран рисует layers: компоненты/WidgetLayer.qml читает и пишет через этот
// синглтон (тумблеры виджетов — из страницы настроек или через toggle).
// Файл — единственный источник правды: атомарная запись (tmp + mv), дебаунс,
// перечитка раз в 60с. Своя запись в полёте блокирует перечитку, чтобы внешний
// дамп не затёр свежее состояние (по образцу core/Reminders.qml, без потери).
Singleton {
    id: store

    readonly property bool ready: store._loaded
    property bool _loaded: false
    property bool _corruptBackupRequired: false
    property bool _corruptBackupPending: false
    property bool _corruptBackupDone: false

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

    function clamp01(value) {
        return Math.max(0, Math.min(1, Number(value)));
    }

    // Дефолтная позиция в долях доступной области для карточки.
    function defPos(id, scrW, scrH, k, itemW, itemH) {
        const d = store.defs[id];
        if (!d)
            return { "rx": 0, "ry": 0 };
        const w = Math.round(d.w * k);
        const h = Math.round(d.h * k);
        const m = Math.round(72 * k);
        const off = Math.round(d.off * k);
        let x, y;
        if (d.col === "tr") {
            x = Math.round(scrW - m - w);
            y = off;
        } else {
            x = m;
            y = Math.round(scrH - m - h - off);
        }
        const maxX = Math.max(1, Number(scrW) - Number(itemW || w));
        const maxY = Math.max(1, Number(scrH) - Number(itemH || h));
        return { "rx": store.clamp01(x / maxX), "ry": store.clamp01(y / maxY) };
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

    // Позиция в долях из store или дефолт; абсолютные legacy-позиции мигрируют ниже.
    function posOf(id, defRx, defRy) {
        const p = store.pos[id];
        return p && isFinite(Number(p.rx)) && isFinite(Number(p.ry))
            ? { "rx": store.clamp01(p.rx), "ry": store.clamp01(p.ry) }
            : { "rx": store.clamp01(defRx), "ry": store.clamp01(defRy) };
    }

    function moveRel(id, rx, ry) {
        if (!store.defs[id] || !isFinite(Number(rx)) || !isFinite(Number(ry)))
            return ;
        const built = {};
        for (const k in store.pos)
            built[k] = store.pos[k];
        built[id] = { "rx": store.clamp01(rx), "ry": store.clamp01(ry) };
        store.pos = built;
        store.scheduleSave();
    }

    // Старые {x,y} превращаем в доли при первом доступном размере/геометрии.
    function migrateLegacy(id, screenW, screenH, itemW, itemH) {
        const p = store.pos[id];
        if (!p || (isFinite(Number(p.rx)) && isFinite(Number(p.ry))))
            return;
        const sw = Number(screenW), sh = Number(screenH);
        const iw = Number(itemW), ih = Number(itemH);
        if (!isFinite(sw) || !isFinite(sh) || !isFinite(iw) || !isFinite(ih)
            || sw <= 0 || sh <= 0 || iw <= 0 || ih <= 0
            || !isFinite(Number(p.x)) || !isFinite(Number(p.y)))
            return;
        const maxX = Math.max(0, sw - iw);
        const maxY = Math.max(0, sh - ih);
        const built = {};
        for (const k in store.pos)
            built[k] = store.pos[k];
        built[id] = {
            "rx": maxX > 0 ? store.clamp01(Number(p.x) / maxX) : 0,
            "ry": maxY > 0 ? store.clamp01(Number(p.y) / maxY) : 0
        };
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
            if (ps && ps[id]) {
                const p = ps[id];
                if (isFinite(Number(p.rx)) && isFinite(Number(p.ry)))
                    out.pos[id] = { "rx": store.clamp01(p.rx), "ry": store.clamp01(p.ry) };
                else if (isFinite(Number(p.x)) && isFinite(Number(p.y)))
                    out.pos[id] = { "x": Math.round(Number(p.x)), "y": Math.round(Number(p.y)) };
            }
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
            if (!store._corruptBackupPending) {
                store._corruptBackupRequired = false;
                store._corruptBackupDone = false;
            }
            store._loaded = true;
        } catch (e) {
            if (!store._corruptBackupRequired) {
                store.enabledMap = ({});
                store.pos = ({});
            }
            store._corruptBackupRequired = true;
            store._loaded = store._corruptBackupDone;
            store.backupCorrupt();
        }
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

        onExited: {
            if (!store._corruptBackupRequired || store._corruptBackupDone)
                store._loaded = true;  // пустой/отсутствующий файл — тоже готово
            if (store._loaded && store._dirty) {
                store._dirty = false;
                store.save();
            }
        }
    }

    Process {
        id: corruptProc

        onExited: (code) => {
            store._corruptBackupPending = false;
            if (code === 0) {
                store._corruptBackupDone = true;
                store._loaded = true;
                if (store._dirty) {
                    store._dirty = false;
                    store.save();
                }
            }
        }
    }

    function backupCorrupt() {
        if (store._corruptBackupPending || store._corruptBackupDone)
            return;
        store._corruptBackupPending = true;
        corruptProc.command = ["cp", "--", store.path, store.path + ".corrupt-" + Date.now()];
        corruptProc.running = true;
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
        if (!store._loaded || (store._corruptBackupRequired && !store._corruptBackupDone)) {
            store._dirty = true;
            return;
        }
        if (store.saving) {
            store._dirty = true;
            return ;
        }
        store.saving = true;
        const j = JSON.stringify({ "enabled": store.enabledMap, "pos": store.pos });
        const dir = Quickshell.env("HOME") + "/.local/state/oberon";
        writeProc.command = ["sh", "-c",
            "mkdir -p " + store.shq(dir) + " && printf %s " + store.shq(j) + " > " + store.shq(store.path + ".tmp") + " && mv -f " + store.shq(store.path + ".tmp") + " " + store.shq(store.path)];
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
