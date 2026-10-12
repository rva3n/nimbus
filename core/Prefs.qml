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
        idleScreenMin: 10,
        idleLockMin: 0,
        idleSuspendMin: 60,
        islandLayout: true,
        islandWeather: true,
        islandClock: true,
        islandWorkspaces: true,
        islandTray: true,
        clockSeconds: true,
        toastSeconds: 5,
        weatherAuto: true,
        weatherCity: "",
        weatherLat: 0,
        weatherLon: 0,
        weatherPlace: "",
        dnd: false,
        themeScheme: "auto",
        themeContrast: 0,
        themeMode: "auto",
        islandOrder: ["kb", "weather", "ws", "clock", "tray"],
        islandAllScreens: false,
        barStyle: "island",
        mediaStyle: "cover",
        soundsEnabled: true,
        nightLightEnabled: false,
        nightLightTemp: 4500,
        nightLightMode: "manual",
        nightLightFrom: "22:00",
        nightLightTo: "07:00",
        dndScheduleEnabled: false,
        dndFrom: "23:00",
        dndTo: "07:00",
        goPlan: "go",
        goChipMode: "auto",
        goWarnPct: 80,
        goRenewDom: 22,
        tilesOrder: "",
        tilesHidden: "",
        widgetsEnabled: false,
        widgetsLayout: {}
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
            property int idleScreenMin: 10
            property int idleLockMin: 0
            property int idleSuspendMin: 60
            property bool islandLayout: true
            property bool islandWeather: true
            property bool islandClock: true
            property bool islandWorkspaces: true
            property bool islandTray: true
            property bool clockSeconds: true
            property int toastSeconds: 5
            property bool weatherAuto: true
            property string weatherCity: ""
            property real weatherLat: 0
            property real weatherLon: 0
            property string weatherPlace: ""
            property bool dnd: false
            property string themeScheme: "auto"
            property real themeContrast: 0
            property string themeMode: "auto"
            property var islandOrder: ["kb", "weather", "ws", "clock", "tray"]
            property bool islandAllScreens: false
            property string barStyle: "island"
            property string mediaStyle: "cover"
            property bool soundsEnabled: true
            property bool nightLightEnabled: false
            property int nightLightTemp: 4500
            property string nightLightMode: "manual"
            property string nightLightFrom: "22:00"
            property string nightLightTo: "07:00"
            property bool dndScheduleEnabled: false
            property string dndFrom: "23:00"
            property string dndTo: "07:00"
            property string goPlan: "go"
            property string goChipMode: "auto"
            property int goWarnPct: 80
            property int goRenewDom: 22
            property string tilesOrder: ""
            property string tilesHidden: ""
            property bool widgetsEnabled: false
            property var widgetsLayout: ({})
        }
    }

    readonly property real uiScale: a.uiScale
    readonly property real cornerScale: a.cornerScale
    readonly property real motionScale: a.motionScale
    readonly property real accentPunch: a.accentPunch
    readonly property real surfaceDarkness: a.surfaceDarkness
    readonly property real surfaceTint: a.surfaceTint
    readonly property real blurAmount: a.blurAmount
    readonly property int idleScreenMin: a.idleScreenMin
    readonly property int idleLockMin: a.idleLockMin
    readonly property int idleSuspendMin: a.idleSuspendMin
    readonly property bool islandLayout: a.islandLayout
    readonly property bool islandWeather: a.islandWeather
    readonly property bool islandClock: a.islandClock
    readonly property bool islandWorkspaces: a.islandWorkspaces
    readonly property bool islandTray: a.islandTray
    readonly property bool clockSeconds: a.clockSeconds
    readonly property int toastSeconds: a.toastSeconds
    readonly property bool weatherAuto: a.weatherAuto
    readonly property string weatherCity: a.weatherCity
    readonly property real weatherLat: a.weatherLat
    readonly property real weatherLon: a.weatherLon
    readonly property string weatherPlace: a.weatherPlace
    readonly property bool dnd: a.dnd
    readonly property string themeScheme: a.themeScheme
    readonly property real themeContrast: a.themeContrast
    readonly property string themeMode: a.themeMode
    readonly property var islandOrder: a.islandOrder
    readonly property bool islandAllScreens: a.islandAllScreens
    readonly property string barStyle: a.barStyle
    readonly property string mediaStyle: a.mediaStyle
    readonly property bool soundsEnabled: a.soundsEnabled
    readonly property bool nightLightEnabled: a.nightLightEnabled
    readonly property int nightLightTemp: a.nightLightTemp
    readonly property string nightLightMode: a.nightLightMode
    readonly property string nightLightFrom: a.nightLightFrom
    readonly property string nightLightTo: a.nightLightTo
    readonly property bool dndScheduleEnabled: a.dndScheduleEnabled
    readonly property string dndFrom: a.dndFrom
    readonly property string dndTo: a.dndTo
    readonly property string goPlan: a.goPlan
    readonly property string goChipMode: a.goChipMode
    readonly property int goWarnPct: a.goWarnPct
    readonly property int goRenewDom: a.goRenewDom
    readonly property string tilesOrder: a.tilesOrder
    readonly property string tilesHidden: a.tilesHidden
    readonly property bool widgetsEnabled: a.widgetsEnabled
    readonly property var widgetsLayout: a.widgetsLayout

    // Инстанцирование ленивых синглтонов: без ссылки на них QML их не создаёт,
    // и NightLight/Sounds никогда бы не отреагировали на эти префы.
    // (Сами они читают Prefs — зацикливания нет: это простые биндинги.)
    readonly property bool soundsHook: Sounds.enabled
    readonly property bool nightLightHook: NightLight.active

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
