import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../core"
import ".."
import "../../ui"

// Корневая страница панели в анатомии Lucid control centre:
// слайдеры громкости/яркости (size m, inactive = surfaceHighest),
// плитки быстрого доступа как горизонтальные QuickTile Lucid (иконка-бейдж,
// заголовок/подпись, шеврон; ON — accentContainer, OFF — surfaceHighest),
// редактор плиток по карандашу (порядок/скрытые в Prefs,
// защитный код:нет ключей → текущий вид) и карточка уведомлений,
// сгруппированная по appName (иконка + имя + Badge-счётчик, строки NotifItem).
ColumnLayout {
    id: rootPage

    property var win: null

    // ── редактор плиток (QuickTile-карандаш) ────────────────────────────
    property bool tilesEditing: false

    visible: win !== null && win.mode === "panel" && win.page === ""
    Layout.fillWidth: true
    spacing: Theme.dp(12)

    // mm:ss для подписи плитки «Таймеры».
    function fmtTimer(sec) {
        const t = Math.max(0, Math.round(sec));
        const m = Math.floor(t / 60);
        const s = t % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ── плитки: каталог + порядок/скрытые ──────────────────────────────
    // Каталог переширяется: новая плитка добавляется сюда (id/иконка/имя)
    // и веткой в tileSubtitle/tileActive/tileTap ниже.
    readonly property var tileCatalog: [
        { "id": "wifi", "icon": "wifi", "label": "Wi-Fi" },
        { "id": "bluetooth", "icon": "bluetooth", "label": "Bluetooth" },
        { "id": "dnd", "icon": "do_not_disturb_on", "label": "DND" },
        { "id": "timers", "icon": "timer", "label": "Таймеры" }
    ]

    // Локальный оверрайд редактора: пока ключей Prefs нет — правки живут
    // в сессии, с появлением ключей уходят в prefs.json.
    property var _tilesOrderOv: null
    property var _tilesHiddenOv: null

    // prefs.json хранит списки как JSON-строки в ключах tilesOrder/tilesHidden
    // (добавляет другой агент). ""/нет ключа/битый JSON → «текущий вид».
    function _parseTileList(s) {
        if (s === undefined || s === null || s === "")
            return null;

        try {
            const v = JSON.parse(String(s));
            return Array.isArray(v) ? v.filter(id => typeof id === "string") : null;
        } catch (e) {
            return null;
        }
    }

    // порядок = сохранённый (очищенный от устаревших id) ∪ каталог в конце
    readonly property var _tilesOrderStored: rootPage._composeOrder(rootPage._parseTileList(Prefs.tilesOrder))
    readonly property var _tilesHiddenStored: {
        const stored = rootPage._parseTileList(Prefs.tilesHidden);
        return stored ? stored.filter(id => rootPage._tilesOrderStored.includes(id)) : [];
    }
    readonly property var tilesOrder: rootPage._tilesOrderOv !== null ? rootPage._tilesOrderOv : rootPage._tilesOrderStored
    readonly property var tilesHidden: rootPage._tilesHiddenOv !== null ? rootPage._tilesHiddenOv : rootPage._tilesHiddenStored
    readonly property var tilesVisible: rootPage.tilesOrder.filter(id => rootPage.tilesHidden.indexOf(id) === -1)
    // скрытые сейчас — кандидат-чипы «+ Добавить»
    readonly property var tilesAddable: rootPage.tilesOrder.filter(id => rootPage.tilesHidden.indexOf(id) !== -1)

    function _composeOrder(stored) {
        const known = rootPage.tileCatalog.map(t => t.id);
        if (!stored)
            return known;

        const kept = stored.filter(id => known.includes(id));
        for (const id of known)
            if (!kept.includes(id))
                kept.push(id);
        return kept;
    }

    function _trySetPref(key, value) {
        try { Prefs.set(key, value); } catch (e) {}
    }

    function persistTiles() {
        if (_tilesOrderOv !== null && typeof Prefs.tilesOrder !== "undefined")
            _trySetPref("tilesOrder", JSON.stringify(_tilesOrderOv));

        if (_tilesHiddenOv !== null && typeof Prefs.tilesHidden !== "undefined")
            _trySetPref("tilesHidden", JSON.stringify(_tilesHiddenOv));
    }

    function hideTile(id) {
        if (rootPage.tilesHidden.indexOf(id) !== -1)
            return;

        if (_tilesOrderOv === null)
            _tilesOrderOv = rootPage.tilesOrder.slice();
        _tilesHiddenOv = rootPage.tilesHidden.concat([id]);
        rootPage.persistTiles();
    }

    function addTile(id) {
        if (rootPage.tilesHidden.indexOf(id) === -1)
            return;

        if (_tilesOrderOv === null)
            _tilesOrderOv = rootPage.tilesOrder.slice();
        _tilesHiddenOv = rootPage.tilesHidden.filter(x => x !== id);
        rootPage.persistTiles();
    }

    // «По умолчанию» — и в сессии, и в prefs.json (пустые ключи = текущий вид)
    function resetTiles() {
        _tilesOrderOv = null;
        _tilesHiddenOv = null;
        if (typeof Prefs.tilesOrder !== "undefined")
            _trySetPref("tilesOrder", "");

        if (typeof Prefs.tilesHidden !== "undefined")
            _trySetPref("tilesHidden", "");
    }

    function tileById(id) {
        for (const t of rootPage.tileCatalog)
            if (t.id === id)
                return t;
        return null;
    }

    function tileSubtitle(id) {
        switch (id) {
        case "wifi":
            return Sys.activeSsid !== "" ? Sys.activeSsid : (Sys.wifiEnabled ? "Не подключено" : "Выключен");
        case "bluetooth":
            return Sys.btEnabled ? "Включён" : "Выключен";
        case "dnd":
            return Notif.dnd ? "Включён" : "Выключен";
        case "timers":
            return Chrono.running ? rootPage.fmtTimer(Chrono.remaining) : "Нет активных";
        }
        return "";
    }

    function tileActive(id) {
        switch (id) {
        case "wifi":
            return Sys.wifiEnabled && Sys.activeSsid !== "";
        case "bluetooth":
            return Sys.btEnabled;
        case "dnd":
            return Notif.dnd;
        case "timers":
            return Chrono.running;
        }
        return false;
    }

    function tileTap(id) {
        if (id === "dnd") {
            Prefs.set("dnd", !Notif.dnd);
            return;
        }
        if (!(rootPage.win && rootPage.win.shell))
            return;

        switch (id) {
        case "wifi":
            Sys.refreshWifi();
            rootPage.win.shell.togglePage("wifi");
            break;
        case "bluetooth":
            Sys.startBtScan();
            rootPage.win.shell.togglePage("bluetooth");
            break;
        case "timers":
            rootPage.win.shell.togglePage("timers");
            break;
        }
    }

    // ── уведомления: группировка по appName ────────────────────────────
    // В панели показывается первый sliceNotifCount записей истории (как
    // раньше — лимит 3); группы сверху — свежие, внутри — свежие сверху
    // (история уже упорядочена). Счётчик группы = число её строк в панели.
    readonly property int sliceNotifCount: 3

    function groupNotifs(h) {
        const groups = [];
        const byApp = {};
        for (let i = 0; i < h.length; i++) {
            const n = h[i];
            if (!n)
                continue;

            const key = n.appName || "";
            let g = byApp[key];
            if (!g) {
                g = { "app": key, "appLabel": key !== "" ? key : "Без приложения", "appIcon": "", "ts": 0, "items": [] };
                byApp[key] = g;
                groups.push(g);
            }
            if (g.appIcon === "" && n.appIcon && n.appIcon !== "")
                g.appIcon = n.appIcon;
            if (n.ts && n.ts > g.ts)
                g.ts = n.ts;
            g.items.push({ "n": n, "i": i });
        }
        groups.sort((a, b) => b.ts - a.ts);
        return groups;
    }

    readonly property var notifGroups: rootPage.groupNotifs((rootPage.win ? Notif.history : []).slice(0, rootPage.sliceNotifCount))

    // ── плитка быстрого доступа Lucid ──────────────────────────────────
    // Бейдж-иконка 44dp слева, заголовок titleSmall + подпись bodySmall,
    // шеврон справа. OFF — surfaceHighest и стадионные торцы,
    // ON — accentContainer и скругление shapeLgInc (фирменный морф Lucid).
    // Тап открывает страницу; в режиме редактирования тап-off и вместо
    // шеврона — круг «×» (удалить из панели).
    component QuickTile: Item {
        id: qt

        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false
        property bool editing: false

        signal tapped()
        signal removed()

        Layout.fillWidth: true
        implicitHeight: Theme.dp(64)
        scale: qtArea.pressed ? 0.98 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }
        }

        Rectangle {
            id: qtBg

            anchors.fill: parent
            radius: qt.active ? Theme.shapeLgInc : Theme.pill(height)
            color: qt.active ? Theme.accentContainer : Theme.mHighest

            Behavior on radius {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }

            StateLayer {
                id: qtArea

                radius: qtBg.radius
                tint: qt.active ? Theme.fgAccentContainer : Theme.text
                onClicked: if (!qt.editing) qt.tapped()
            }
        }

        Rectangle { // бейдж-иконка 44dp
            id: badge

            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(44)
            height: Theme.dp(44)
            radius: width / 2
            color: qt.active ? Theme.alpha(Theme.fgAccentContainer, 0.14) : Theme.alpha(Theme.text, 0.08)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }

            Icon {
                anchors.centerIn: parent
                name: qt.icon
                size: Theme.dp(22)
                fill: qt.active ? 1 : 0
                color: qt.active ? Theme.fgAccentContainer : Theme.text

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }
        }

        Column { // заголовок + подпись
            anchors.left: badge.right
            anchors.leftMargin: Theme.dp(10)
            anchors.right: chevronSlot.left
            anchors.rightMargin: Theme.dp(2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            LText {
                width: parent.width
                role: "titleSmall"
                weight: 600
                text: qt.label
                color: qt.active ? Theme.fgAccentContainer : Theme.text
                elide: Text.ElideRight
            }

            LText {
                width: parent.width
                visible: text !== ""
                role: "bodySmall"
                text: qt.subtitle
                color: qt.active ? Theme.alpha(Theme.fgAccentContainer, 0.78) : Theme.subtext
                elide: Text.ElideRight
            }
        }

        Item { // правый слот: шеврон / «×» в режиме редактирования
            id: chevronSlot

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(36)
            height: qt.height

            Icon {
                id: chevron

                anchors.centerIn: parent
                visible: !qt.editing
                name: "chevron_right"
                size: Theme.dp(20)
                color: qt.active ? Theme.fgAccentContainer : Theme.subtext
            }

            IconButton {
                anchors.centerIn: parent
                visible: qt.editing
                icon: "close"
                size: "xs"
                variant: "filled"
                onClicked: qt.removed()
            }
        }
    }

    // ── слайдеры громкости и яркости (Lucid size m) ────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(10)

        Slider {
            Layout.fillWidth: true
            size: "m"
            icon: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio.muted ? "volume_off" : "volume_up"
            value: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0
            inactiveColor: Theme.mHighest
            onMoved: (v) => { if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.volume = v; }
            onCommitted: (v) => { if (Pipewire.defaultAudioSink) Pipewire.defaultAudioSink.audio.volume = v; }
            onIconClicked: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("volume")
        }

        Slider {
            Layout.fillWidth: true
            size: "m"
            icon: "brightness_6"
            value: Sys.brightnessFraction
            inactiveColor: Theme.mHighest
            onCommitted: (v) => { Sys.setBrightnessPct(v * 100); }
            onIconClicked: if (rootPage.win && rootPage.win.shell) rootPage.win.shell.togglePage("brightness")
        }
    }

    // ── плитки быстрого доступа: шапка с карандашом + сетка 2 колонки ──
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.dp(8)

        RowLayout { // шапка секции: имя режима + сброс + карандаш
            Layout.fillWidth: true
            spacing: Theme.dp(4)

            LText {
                Layout.fillWidth: true
                role: "labelLarge"
                color: Theme.subtext
                text: rootPage.tilesEditing ? "Редактирование плиток" : "Плитки"
                elide: Text.ElideRight
            }

            Button {
                visible: rootPage.tilesEditing
                variant: "text"
                size: "s"
                icon: "restart_alt"
                text: "По умолчанию"
                onClicked: rootPage.resetTiles()
            }

            IconButton {
                icon: "edit"
                size: "s"
                checkable: true
                checked: rootPage.tilesEditing
                onToggled: (v) => rootPage.tilesEditing = v
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.dp(10)
            rowSpacing: Theme.dp(10)

            Repeater {
                model: rootPage.tilesVisible

                delegate: QuickTile {
                    required property string modelData

                    editing: rootPage.tilesEditing
                    icon: rootPage.tileById(modelData) ? rootPage.tileById(modelData).icon : ""
                    label: rootPage.tileById(modelData) ? rootPage.tileById(modelData).label : modelData
                    active: rootPage.tileActive(modelData)
                    subtitle: rootPage.tileSubtitle(modelData)
                    onTapped: rootPage.tileTap(modelData)
                    onRemoved: rootPage.hideTile(modelData)
                }
            }
        }

        RowLayout { // каталог скрытых плиток в режиме редактирования
            visible: rootPage.tilesEditing && rootPage.tilesAddable.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Theme.dp(4)
            spacing: Theme.dp(6)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: "add"
                size: Theme.dp(16)
                color: Theme.subtextDim
            }

            LText {
                Layout.alignment: Qt.AlignVCenter
                role: "labelSmall"
                color: Theme.subtextDim
                text: "Добавить:"
            }

            Repeater {
                model: rootPage.tilesAddable

                delegate: Chip {
                    required property string modelData

                    kind: "assist"
                    icon: "add"
                    label: rootPage.tileById(modelData) ? rootPage.tileById(modelData).label : modelData
                    onClicked: rootPage.addTile(modelData)
                }
            }
        }

        LText {
            visible: rootPage.tilesEditing && rootPage.tilesVisible.length === 0
            role: "bodySmall"
            color: Theme.subtextDim
            text: "Все плитки скрыты — верните хотя бы одну."
        }
    }

    // ── уведомления: карточка видна только при наличии истории ─────────
    Card {
        visible: Notif.history.length > 0
        Layout.fillWidth: true
        title: "Уведомления"
        actionIcon: "delete"
        onActionClicked: Notif.clearAll()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            Repeater {
                model: rootPage.notifGroups

                delegate: ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout { // заголовок приложения + счётчик
                        Layout.fillWidth: true
                        spacing: Theme.dp(8)

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Theme.dp(20)
                            implicitHeight: Theme.dp(20)
                            radius: Theme.radiusPill
                            color: Theme.accentContainer

                            AppIcon {
                                anchors.centerIn: parent
                                visible: modelData.appIcon !== ""
                                source: modelData.appIcon
                                size: 13
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: modelData.appIcon === ""
                                name: "notifications"
                                size: Theme.dp(12)
                                color: Theme.fgAccentContainer
                            }
                        }

                        LText {
                            role: "titleSmall"
                            color: Theme.text
                            elide: Text.ElideRight
                            text: modelData.appLabel
                        }

                        Badge {
                            Layout.alignment: Qt.AlignVCenter
                            count: modelData.items.length
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Repeater {
                        model: modelData.items

                        delegate: NotifItem {
                            required property var modelData

                            Layout.fillWidth: true
                            item: modelData.n
                            itemIndex: modelData.i
                            showApp: false
                        }
                    }
                }
            }
        }
    }
}
