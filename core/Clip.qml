pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist + pinned items.
Singleton {
    id: c

    property var items: []
    property var pins: []
    property bool loading: false

    // накопитель текущего прогона cliphist — items меняется один раз за цикл,
    // иначе ListView пересобирается на каждой строке и список «дрожит»
    property var _buf: []

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    // Keep capturing the clipboard.
    Process {
        id: storeProc
        command: ["sh", "-c", "wl-paste --watch cliphist store"]
        running: true
    }

    // List entries and decode image thumbnails.
    Process {
        id: scanProc
        command: ["sh", "-c",
            "C=\"$HOME/.cache/oberon/clip\"; mkdir -p \"$C\"; " +
            "cliphist list 2>/dev/null | head -60 | sed 's/\\t/|/' | while IFS='|' read -r id rest; do " +
            "case \"$rest\" in *\"binary data\"*) cliphist decode \"$id\" > \"$C/$id.png\" 2>/dev/null; printf '%s|image|%s\\n' \"$id\" \"$rest\";; " +
            "*) printf '%s|text|%s\\n' \"$id\" \"$rest\";; esac; done"]
        stdout: SplitParser { onRead: line => c.parseEntry(line) }
        onExited: {
            // slice(): гарантируем новый массив — присваивание того же
            // объекта не шлёт change-сигнал (refresh вызывается дважды)
            c.items = c._buf.slice();
            c.loading = false;
        }
    }
    function parseEntry(line) {
        const i = line.indexOf("|"); if (i < 0) return;
        const j = line.indexOf("|", i + 1); if (j < 0) return;
        const id = line.slice(0, i);
        c._buf.push({
            id: id,
            type: line.slice(i + 1, j),
            preview: line.slice(j + 1),
            thumb: Quickshell.env("HOME") + "/.cache/oberon/clip/" + id + ".png"
        });
    }

    Process {
        id: pinsProc
        // jq -c: файл пишется многострочным, а SplitParser читает по строкам
        command: ["sh", "-c", "cat " + shq(Quickshell.env("HOME") + "/.local/state/oberon/pins.json") + " 2>/dev/null | jq -c . 2>/dev/null"]
        stdout: SplitParser { onRead: line => { try { c.pins = JSON.parse(line); } catch (e) { c.pins = []; } } }
    }
    function loadPins() { pinsProc.running = false; pinsProc.running = true; }

    // обновление: старый список остаётся на экране, пока не готов новый —
    // без «мигания» пустотой; items присваивается один раз в onExited
    function refresh() { c._buf = []; c.loading = true; scanProc.running = false; scanProc.running = true; c.loadPins(); }

    function copy(id, type) {
        const mime = (type === "image") ? " --type image/png" : "";
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + shq(id) + " | wl-copy" + mime]);
    }
    // cliphist и jq пишут в фоне (execDetached не ждёт завершения), поэтому
    // после удаления/закрепления перечитываем списки спустя короткую паузу —
    // иначе UI показывает старое состояние до повторного открытия вкладки
    Timer {
        id: resync
        interval: 350
        onTriggered: c.refresh()
    }
    function refreshLater() { resync.restart() }

    // cliphist delete принимает строку из stdin и сверяет её с записью целиком
    // (id идёт первым полем), поэтому находим строку по id и передаём как есть;
    // строку из списка убираем сразу — UI не ждёт cliphist
    function del(id) {
        c.items = c.items.filter(function (it) { return String(it.id) !== String(id); });
        Quickshell.execDetached(["sh", "-c",
            "LINE=$(cliphist list 2>/dev/null | awk -F'\\t' -v id=" + shq(id)
            + " '$1 == id { print; exit }'); "
            + "[ -n \"$LINE\" ] && printf '%s' \"$LINE\" | cliphist delete"]);
        refreshLater();
    }
    function wipe() { Quickshell.execDetached(["sh", "-c", "cliphist wipe"]); c.items = []; }
    function pin(id) { Quickshell.execDetached(["sh", "-c", "bash " + shq(Quickshell.env("HOME") + "/oberon/scripts/clip-pin.sh") + " " + shq(id)]); refreshLater(); }
    function unpin(id) { Quickshell.execDetached(["sh", "-c", "bash " + shq(Quickshell.env("HOME") + "/oberon/scripts/clip-unpin.sh") + " " + shq(id)]); refreshLater(); }
    function copyPin(p) {
        if (p.type === "image") Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + shq(p.file)]);
        else Quickshell.execDetached(["sh", "-c", "printf %s " + shq(p.text) + " | wl-copy"]);
    }
}
