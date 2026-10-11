pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Пользовательские настройки Nimbus: ~/nimbus/prefs.json.
// Читаются реактивно, пишутся страницей «Настройки» (или руками).
Singleton {
    id: p

    readonly property string path: Quickshell.env("HOME") + "/nimbus/prefs.json"
    readonly property bool ready: file.loaded

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    readonly property string defaultsJson: JSON.stringify({
        uiScale: 1,
        cornerScale: 1,
        motionScale: 1,
        accentPunch: 1,
        surfaceDarkness: -1,
        surfaceTint: -1,
        blurAmount: 45,
        weatherAuto: true,
        weatherCity: "",
        weatherLat: 0,
        weatherLon: 0,
        weatherPlace: "",
        dnd: false
    })

    Process {
        id: seedProc
        command: ["sh", "-c",
            "test -f " + shq(p.path) + " || { mkdir -p \"$(dirname " + shq(p.path) + ")\"; printf %s " + shq(p.defaultsJson) + " > " + shq(p.path) + "; }"]
    }

    FileView {
        id: file
        path: p.path
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: seedProc.running = true
        onLoadedChanged: if (loaded) p.fillMissingDefaults()
        adapter: JsonAdapter {
            id: a
            property real uiScale: 1
            property real cornerScale: 1
            property real motionScale: 1
            property real accentPunch: 1
            property real surfaceDarkness: -1
            property real surfaceTint: -1
            property real blurAmount: 45
            property bool weatherAuto: true
            property string weatherCity: ""
            property real weatherLat: 0
            property real weatherLon: 0
            property string weatherPlace: ""
            property bool dnd: false
        }
    }

    readonly property real uiScale: a.uiScale
    readonly property real cornerScale: a.cornerScale
    readonly property real motionScale: a.motionScale
    readonly property real accentPunch: a.accentPunch
    readonly property real surfaceDarkness: a.surfaceDarkness
    readonly property real surfaceTint: a.surfaceTint
    readonly property real blurAmount: a.blurAmount
    readonly property bool weatherAuto: a.weatherAuto
    readonly property string weatherCity: a.weatherCity
    readonly property real weatherLat: a.weatherLat
    readonly property real weatherLon: a.weatherLon
    readonly property string weatherPlace: a.weatherPlace
    readonly property bool dnd: a.dnd

    // Добить ключи, которых нет в существующем файле: JsonAdapter оставляет
    // их неопределёнными — иначе ловим "Unable to assign [undefined] to bool".
    function fillMissingDefaults() {
        const d = JSON.parse(p.defaultsJson);
        let fixed = false;
        for (const k of Object.keys(d)) {
            if (a[k] === undefined) {
                a[k] = d[k];
                fixed = true;
            }
        }
        if (fixed) file.writeAdapter();
    }

    // Установить значение (ключ = имя свойства адаптера) и сохранить файл.
    function set(key, value) {
        a[key] = value;
        file.writeAdapter();
    }

    Component.onCompleted: {
        if (!file.loaded)
            seedProc.running = true;
        else
            fillMissingDefaults();
    }
}
