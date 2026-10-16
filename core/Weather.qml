pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Погода через Open-Meteo (без ключа). Локация — авто по IP (ipapi.co) или
// город из prefs.json (weatherAuto=false, weatherCity). Обновление раз в 15 мин.
Singleton {
    id: w

    property bool loading: false
    property string error: ""
    property string place: Prefs.weatherPlace
    property real lat: 0
    property real lon: 0

    // текущие условия
    property real temp: 0
    property real feels: 0
    property real humidity: 0
    property real wind: 0
    property int code: -1
    property bool isDay: true

    property var hourly: []   // [{ label, temp, code }]
    property var daily: []    // [{ day, min, max, code }]
    property double updatedAt: 0

    readonly property bool hasData: code >= 0
    readonly property string icon: hasData ? wmoIcon(code, isDay) : "wb_sunny"
    readonly property string desc: hasData ? wmoText(code) : ""

    // служебные
    property bool _geoGot: false
    property bool _wxGot: false

    function wmoIcon(c, day) {
        if (c === 0) return day ? "sunny" : "bedtime";
        if (c <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if (c === 3) return "cloud";
        if (c === 45 || c === 48) return "foggy";
        if (c >= 51 && c <= 67) return "rainy";
        if (c >= 71 && c <= 77) return "weather_snowy";
        if (c >= 80 && c <= 82) return "rainy";
        if (c === 85 || c === 86) return "weather_snowy";
        if (c >= 95) return "thunderstorm";
        return "cloud";
    }

    function wmoText(c) {
        if (c === 0) return "Ясно";
        if (c === 1) return "Почти ясно";
        if (c === 2) return "Переменная облачность";
        if (c === 3) return "Пасмурно";
        if (c === 45 || c === 48) return "Туман";
        if (c >= 51 && c <= 57) return "Морось";
        if (c >= 61 && c <= 67) return "Дождь";
        if (c >= 71 && c <= 77) return "Снег";
        if (c >= 80 && c <= 82) return "Ливень";
        if (c === 85 || c === 86) return "Снегопад";
        if (c >= 95) return "Гроза";
        return "—";
    }

    function _fail(msg) {
        w.loading = false;
        w.error = msg;
    }

    // ── локация по IP ──────────────────────────────────────────────────
    Process {
        id: geoProc
        command: ["sh", Quickshell.env("HOME") + "/oberon/scripts/geo.sh"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    if (!j || typeof j.lat !== "number" || typeof j.lon !== "number") {
                        w._fail("Не удалось определить город");
                        return;
                    }
                    w._geoGot = true;
                    w.place = j.city || "";
                    w.lat = j.lat;
                    w.lon = j.lon;
                    Prefs.set("weatherPlace", w.place);
                    w.fetch();
                } catch (e) {
                    w._fail("Ошибка определения города");
                }
            }
        }
        onExited: {
            if (!w._geoGot && w.loading) {
                if (Prefs.weatherLat !== 0) {
                    w.lat = Prefs.weatherLat;
                    w.lon = Prefs.weatherLon;
                    w.place = Prefs.weatherPlace;
                    w.fetch();
                } else {
                    w._fail("Не удалось определить город по IP");
                }
            }
        }
    }

    // ── геокодинг ручного города ───────────────────────────────────────
    Process {
        id: geocodeProc
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    if (!j || typeof j.latitude !== "number") {
                        w._fail("Город не найден");
                        return;
                    }
                    w._geoGot = true;
                    w.place = j.name || Prefs.weatherCity;
                    w.lat = j.latitude;
                    w.lon = j.longitude;
                    Prefs.set("weatherLat", w.lat);
                    Prefs.set("weatherLon", w.lon);
                    Prefs.set("weatherPlace", w.place);
                    w.fetch();
                } catch (e) {
                    w._fail("Ошибка геокодинга");
                }
            }
        }
        onExited: if (!w._geoGot && w.loading)
            w._fail("Город не найден")
    }

    // ── прогноз ────────────────────────────────────────────────────────
    Process {
        id: wxProc
        stdout: SplitParser {
            onRead: line => {
                try {
                    w._parse(line);
                } catch (e) {
                    w._fail("Ошибка разбора прогноза");
                }
            }
        }
        onExited: {
            if (w._wxGot) {
                w.error = "";
                w.updatedAt = Date.now();
            } else if (w.loading) {
                w._fail("Нет данных о погоде");
            }
            w.loading = false;
        }
    }

    function _parse(line) {
        const j = JSON.parse(line);
        const cur = j.current || {};

        w.temp = Math.round(cur.temperature_2m);
        w.feels = Math.round(cur.apparent_temperature);
        w.humidity = Math.round(cur.relative_humidity_2m);
        w.wind = Math.round(cur.wind_speed_10m);
        w.code = Math.round(cur.weather_code);
        w.isDay = cur.is_day === 1;

        const h = j.hourly || {};
        const hTimes = h.time || [];
        const hTemps = h.temperature_2m || [];
        const hCodes = h.weather_code || [];
        const now = new Date();
        const hourFloor = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours());
        let start = 0;
        for (let i = 0; i < hTimes.length; i++) {
            if (new Date(hTimes[i]) >= hourFloor) {
                start = i;
                break;
            }
        }
        const hours = [];
        for (let i = start; i < Math.min(hTimes.length, start + 12); i++) {
            const d = new Date(hTimes[i]);
            hours.push({
                label: ("0" + d.getHours()).slice(-2) + ":00",
                temp: Math.round(hTemps[i]),
                code: Math.round(hCodes[i])
            });
        }
        w.hourly = hours;

        const d0 = j.daily || {};
        const dTimes = d0.time || [];
        const dCodes = d0.weather_code || [];
        const dMax = d0.temperature_2m_max || [];
        const dMin = d0.temperature_2m_min || [];
        const DAYS = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
        const days = [];
        for (let i = 0; i < Math.min(6, dTimes.length); i++) {
            const d = new Date(dTimes[i]);
            days.push({
                day: i === 0 ? "Сегодня" : DAYS[d.getDay()],
                min: Math.round(dMin[i]),
                max: Math.round(dMax[i]),
                code: Math.round(dCodes[i])
            });
        }
        w.daily = days;

        w._wxGot = true;
    }

    function refresh() {
        w.error = "";
        w.loading = true;
        w._geoGot = false;
        w._wxGot = false;

        if (Prefs.weatherAuto) {
            geoProc.running = false;
            geoProc.running = true;
        } else if (Prefs.weatherCity !== "") {
            const q = encodeURIComponent(Prefs.weatherCity);
            geocodeProc.command = ["sh", "-c",
                "curl -s --max-time 15 'https://geocoding-api.open-meteo.com/v1/search?name=" + q + "&count=1&language=ru&format=json' | jq -c '.results[0] // empty' 2>/dev/null"];
            geocodeProc.running = false;
            geocodeProc.running = true;
        } else if (Prefs.weatherLat !== 0) {
            w.lat = Prefs.weatherLat;
            w.lon = Prefs.weatherLon;
            w.place = Prefs.weatherPlace;
            w.fetch();
        } else {
            w._fail("Город не задан");
        }
    }

    function fetch() {
        const url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + w.lat + "&longitude=" + w.lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=auto&forecast_days=6";
        wxProc.command = ["sh", "-c", "curl -s --max-time 20 '" + url + "' | jq -c '.' 2>/dev/null"];
        wxProc.running = false;
        wxProc.running = true;
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: w.refresh()
    }

    // смена режима/города в настройках — сразу перезапрашиваем
    Connections {
        target: Prefs

        function onWeatherAutoChanged() { w.refresh() }
        function onWeatherCityChanged() { w.refresh() }
    }

    Component.onCompleted: refresh()
}
