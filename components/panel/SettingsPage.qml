import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"
import ".."

// Страница «Настройки» — двухколоночный layout в духе Lucid: слева рейл
// разделов (180), справа — содержимое выбранного пункта. Ширину панели (620)
// задаёт Island, контент невелик, поэтому прокрутка не нужна.
// Внешний вид и погода пишут в Prefs → ~/nimbus/prefs.json.
RowLayout {
    id: page

    property var win: null
    // выбранный раздел: 0 — шелл, 1 — островок, 2 — питание,
    // 3 — уведомления, 4 — погода, 5 — композитор, 6 — ввод, 7 — экран
    property int section: 0

    // имя монитора, на котором открыта панель (для раздела «Экран»)
    readonly property string outputName: page.win && page.win.screen ? String(page.win.screen.name) : ""
    // текущие значения настроек Umbriel, прочитанные из umbriel-settings.py
    property var umb: ({})

    visible: win !== null && win.mode === "panel" && win.page === "settings"
    Layout.fillWidth: true
    spacing: Theme.dp(16)

    // при каждом открытии страницы — первый раздел и свежие настройки Umbriel
    onVisibleChanged: if (visible) { page.section = 0; page.reloadUmb() }

    // смена раздела — подтягиваем актуальные значения из конфигов Umbriel
    onSectionChanged: page.reloadUmb()

    // однократное чтение настроек Umbriel (один JSON в строке)
    Process {
        id: umbRead

        command: ["python3", Quickshell.env("HOME") + "/nimbus/scripts/umbriel-settings.py", "read"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try { page.umb = JSON.parse(line); } catch (e) {}
            }
        }
    }

    // отложенный повторный опрос после записи (config-reload асинхронен)
    Timer {
        id: umbReloadTimer

        interval: 600
        onTriggered: page.reloadUmb()
    }

    // перезапустить чтение настроек Umbriel
    function reloadUmb() {
        umbRead.running = false;
        umbRead.running = true;
    }

    // значение из прочитанных настроек Umbriel или запасное
    function umbVal(key, fallback) {
        const v = page.umb[key];
        return v === undefined ? fallback : v;
    }

    // записать значение в конфиг Umbriel (file, section, key, tomlValue) и обновить
    function setUmb(file, section, key, tomlValue) {
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/nimbus/scripts/umbriel-settings.py",
                                 "set", file, section, key, String(tomlValue)]);
        umbReloadTimer.restart();
    }

    function applyCity() {
        Prefs.set("weatherCity", cityField.text.trim());
    }

    // Применить таймауты питания (hypridle) — сразу после смены настроек.
    function applyIdle() {
        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/nimbus/scripts/set-idle.sh",
                                 String(Prefs.idleScreenMin), String(Prefs.idleLockMin), String(Prefs.idleSuspendMin)]);
    }

    // ── локальные компоненты ──────────────────────────────────────────

    // заголовок раздела справа: titleMedium + пояснение
    component SectionHeader: ColumnLayout {
        id: sh

        property string title: ""
        property string caption: ""

        Layout.fillWidth: true
        Layout.bottomMargin: Theme.dp(2)
        spacing: Theme.dp(2)

        Text {
            Layout.fillWidth: true
            text: sh.title
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("titleMedium")
            font.weight: Theme.typeWeight("titleMedium")
        }

        Text {
            Layout.fillWidth: true
            visible: sh.caption !== ""
            text: sh.caption
            color: Theme.subtext
            wrapMode: Text.WordWrap
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
        }
    }

    // пункт рейла: высота 48, radiusMd; выбранный — accentContainer и
    // fgAccentContainer, ховер — bgHover; иконка в контейнере 40×40 radiusMd
    component NavItem: Item {
        id: ni

        property string icon: ""
        property string label: ""
        property bool selected: false

        signal clicked()

        Layout.fillWidth: true
        implicitHeight: Theme.dp(48)

        Rectangle {
            id: bg

            anchors.fill: parent
            radius: Theme.radiusMd
            color: ni.selected ? Theme.accentContainer
                               : (area.containsMouse ? Theme.bgHover : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.durDefaultEffects }
            }

            // state layer поверх выбранного (ховер/нажатие)
            Rectangle {
                anchors.fill: parent
                radius: bg.radius
                color: Theme.fgAccentContainer
                opacity: ni.selected ? (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0)) : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.ms(100); easing.type: Theme.easeStandard }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(4)
            anchors.rightMargin: Theme.dp(12)
            spacing: Theme.dp(12)

            Rectangle { // контейнер иконки 40×40
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.dp(40)
                implicitHeight: Theme.dp(40)
                radius: Theme.radiusMd
                color: "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: ni.icon
                    size: Theme.dp(20)
                    color: ni.selected ? Theme.fgAccentContainer : Theme.subtext
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: ni.label
                color: ni.selected ? Theme.fgAccentContainer : Theme.text
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelLarge")
                font.weight: Theme.typeWeight("labelLarge")
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ni.clicked()
        }
    }

    // строка параметра: подпись + значение, ниже слайдер min..max
    component ParamRow: ColumnLayout {
        id: pr

        property string label: ""
        property real min: 0
        property real max: 1
        property real value: 1
        // формат подписи справа: value * displayMul + suffix
        property real displayMul: 100
        property string suffix: "%"

        signal committed(real v)

        Layout.fillWidth: true
        spacing: Theme.dp(2)

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(8)

            Text {
                Layout.fillWidth: true
                text: pr.label
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodyLarge")
                font.weight: Theme.typeWeight("bodyLarge")
            }

            Text {
                text: Math.round(pr.value * pr.displayMul) + pr.suffix
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelMedium")
                font.weight: Theme.typeWeight("labelMedium")
            }
        }

        Slider {
            Layout.fillWidth: true
            value: pr.max > pr.min ? (pr.value - pr.min) / (pr.max - pr.min) : 0
            onCommitted: (v) => pr.committed(pr.min + v * (pr.max - pr.min))
        }
    }

    // строка-переключатель: подпись + Switch
    component ToggleRow: RowLayout {
        id: tr

        property string label: ""
        property bool checked: false

        signal toggled(bool value)

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.dp(40)
        spacing: Theme.dp(8)

        Text {
            Layout.fillWidth: true
            text: tr.label
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyLarge")
            font.weight: Theme.typeWeight("bodyLarge")
        }

        Switch {
            id: sw
            Layout.alignment: Qt.AlignVCenter
            checked: tr.checked
            onToggled: tr.toggled(sw.checked)
        }
    }

    // строка выбора из набора значений: ‹ значение ›
    component ChoiceRow: RowLayout {
        id: cr

        property string label: ""
        property var values: []
        property var labels: []
        property var value: 0

        signal committed(var v)

        function _idx() {
            for (let i = 0; i < cr.values.length; i++)
                if (cr.values[i] === cr.value) return i;
            return 0;
        }
        function _step(d) {
            const i = cr._idx();
            const ni = Math.max(0, Math.min(cr.values.length - 1, i + d));
            const nv = cr.values[ni];
            if (nv !== cr.value) cr.committed(nv);
        }

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.dp(40)
        spacing: Theme.dp(8)

        Text {
            Layout.fillWidth: true
            text: cr.label
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyLarge")
            font.weight: Theme.typeWeight("bodyLarge")
        }

        IconButton {
            icon: "chevron_left"
            size: "s"
            variant: "standard"
            onClicked: cr._step(-1)
        }

        Text {
            text: cr.labels[cr._idx()] || ""
            color: Theme.subtext
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: Theme.dp(64)
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelMedium")
            font.weight: Theme.typeWeight("labelMedium")
        }

        IconButton {
            icon: "chevron_right"
            size: "s"
            variant: "standard"
            onClicked: cr._step(1)
        }
    }

    // ── левая колонка: рейл разделов ──────────────────────────────────
    ColumnLayout {
        id: rail

        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: Theme.dp(180)
        spacing: Theme.dp(4)

        NavItem {
            icon: "tune"
            label: "Шелл"
            selected: page.section === 0
            onClicked: page.section = 0
        }
        NavItem {
            icon: "widgets"
            label: "Островок"
            selected: page.section === 1
            onClicked: page.section = 1
        }
        NavItem {
            icon: "power"
            label: "Питание"
            selected: page.section === 2
            onClicked: page.section = 2
        }
        NavItem {
            icon: "notifications"
            label: "Уведомления"
            selected: page.section === 3
            onClicked: page.section = 3
        }
        NavItem {
            icon: "sunny"
            label: "Погода"
            selected: page.section === 4
            onClicked: page.section = 4
        }
        NavItem {
            icon: "dashboard"
            label: "Композитор"
            selected: page.section === 5
            onClicked: page.section = 5
        }
        NavItem {
            icon: "keyboard"
            label: "Ввод"
            selected: page.section === 6
            onClicked: page.section = 6
        }
        NavItem {
            icon: "desktop_windows"
            label: "Экран"
            selected: page.section === 7
            onClicked: page.section = 7
        }
    }

    // ── правая колонка: содержимое выбранного раздела ─────────────────
    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Theme.dp(10)

        // 1. Интерфейс
        ColumnLayout {
            visible: page.section === 0
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Шелл"
                caption: "Оформление Nimbus: масштаб, форма, движение и цвет"
            }

            Card { // масштаб
                Layout.fillWidth: true
                title: "Масштаб"

                ParamRow {
                    label: "Размер интерфейса"
                    min: 0.8
                    max: 1.25
                    value: Prefs.uiScale
                    onCommitted: (v) => Prefs.set("uiScale", v)
                }
                ParamRow {
                    label: "Скругления"
                    min: 0
                    max: 1.5
                    value: Prefs.cornerScale
                    onCommitted: (v) => Prefs.set("cornerScale", v)
                }
            }

            Card { // движение и цвет
                Layout.fillWidth: true
                title: "Движение и цвет"

                ParamRow {
                    label: "Скорость анимаций"
                    min: 0.5
                    max: 1.5
                    value: Prefs.motionScale
                    onCommitted: (v) => Prefs.set("motionScale", v)
                }
                ParamRow {
                    label: "Насыщенность акцента"
                    min: 0.5
                    max: 1.5
                    value: Prefs.accentPunch
                    onCommitted: (v) => Prefs.set("accentPunch", v)
                }

                ParamRow {
                    label: "Размытие фона"
                    min: 0
                    max: 100
                    value: Prefs.blurAmount
                    displayMul: 1
                    suffix: "%"
                    onCommitted: (v) => {
                        const r = Math.round(v);
                        Prefs.set("blurAmount", r);
                        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/nimbus/scripts/set-blur.sh", String(r)]);
                    }
                }

                ParamRow {
                    label: "Затемнение поверхностей"
                    min: 0
                    max: 1.5
                    value: Math.max(0, Prefs.surfaceDarkness)
                    onCommitted: (v) => Prefs.set("surfaceDarkness", Math.round(v * 20) / 20)
                }
                ParamRow {
                    label: "Тонировка поверхностей"
                    min: 0
                    max: 1
                    value: Math.max(0, Prefs.surfaceTint)
                    onCommitted: (v) => Prefs.set("surfaceTint", Math.round(v * 20) / 20)
                }

                Text { // пояснение к ползунку размытия
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dp(2)
                    text: "Интенсивность размытия фона (радиус Umbriel; влияет и на окна). 0% — без размытия, 100% — максимум."
                    color: Theme.subtextDim
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }

        // 2. Островок
        ColumnLayout {
            visible: page.section === 1
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Островок"
                caption: "Что показывать в капсуле"
            }

            Card {
                Layout.fillWidth: true

                ToggleRow {
                    label: "Показывать раскладку клавиатуры"
                    checked: Prefs.islandLayout
                    onToggled: (v) => Prefs.set("islandLayout", v)
                }
                ToggleRow {
                    label: "Показывать погоду"
                    checked: Prefs.islandWeather
                    onToggled: (v) => Prefs.set("islandWeather", v)
                }
                ToggleRow {
                    label: "Секунды в часах"
                    checked: Prefs.clockSeconds
                    onToggled: (v) => Prefs.set("clockSeconds", v)
                }
                ToggleRow {
                    label: "Показывать часы"
                    checked: Prefs.islandClock
                    onToggled: (v) => Prefs.set("islandClock", v)
                }
                ToggleRow {
                    label: "Показывать воркспейсы"
                    checked: Prefs.islandWorkspaces
                    onToggled: (v) => Prefs.set("islandWorkspaces", v)
                }
                ToggleRow {
                    label: "Показывать трей"
                    checked: Prefs.islandTray
                    onToggled: (v) => Prefs.set("islandTray", v)
                }
            }
        }

        // 3. Питание
        ColumnLayout {
            visible: page.section === 2
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Питание"
                caption: "Что и когда делать при бездействии"
            }

            Card {
                Layout.fillWidth: true

                ChoiceRow {
                    label: "Гасить экран через"
                    values: [0, 1, 2, 5, 10, 15, 30, 60]
                    labels: ["Никогда", "1 мин", "2 мин", "5 мин", "10 мин", "15 мин", "30 мин", "60 мин"]
                    value: Prefs.idleScreenMin
                    onCommitted: (v) => { Prefs.set("idleScreenMin", v); page.applyIdle() }
                }
                ChoiceRow {
                    label: "Блокировать через"
                    values: [0, 1, 2, 5, 10, 15, 30]
                    labels: ["Никогда", "1 мин", "2 мин", "5 мин", "10 мин", "15 мин", "30 мин"]
                    value: Prefs.idleLockMin
                    onCommitted: (v) => { Prefs.set("idleLockMin", v); page.applyIdle() }
                }
                ChoiceRow {
                    label: "Уходить в сон через"
                    values: [0, 15, 30, 60, 120, 180]
                    labels: ["Никогда", "15 мин", "30 мин", "60 мин", "2 часа", "3 часа"]
                    value: Prefs.idleSuspendMin
                    onCommitted: (v) => { Prefs.set("idleSuspendMin", v); page.applyIdle() }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dp(2)
                    text: "Работает через hypridle (Umbriel): гашение — DPMS, блокировка — экран Nimbus, сон — systemd. Если монитор гаснет раньше выбранного — это его собственный таймер в прошивке."
                    color: Theme.subtextDim
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }

        // 4. Уведомления
        ColumnLayout {
            visible: page.section === 3
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Уведомления"
                caption: "Тосты и режим «не беспокоить»"
            }

            Card {
                Layout.fillWidth: true

                ToggleRow {
                    label: "Не беспокоить (DND)"
                    checked: Prefs.dnd
                    onToggled: (v) => Prefs.set("dnd", v)
                }
                ParamRow {
                    label: "Длительность тоста"
                    min: 2
                    max: 10
                    value: Prefs.toastSeconds
                    displayMul: 1
                    suffix: " сек"
                    onCommitted: (v) => Prefs.set("toastSeconds", Math.round(v))
                }
            }
        }

        // 5. Погода
        ColumnLayout {
            visible: page.section === 4
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Погода"
                caption: "Автоопределение или ручной выбор города"
            }

            Card {
                Layout.fillWidth: true

                RowLayout { // авто-определение города
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.dp(48)
                    spacing: Theme.dp(12)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: "Определять город автоматически"
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyLarge")
                            font.weight: Theme.typeWeight("bodyLarge")
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: Prefs.weatherAuto
                            text: "По IP-адресу"
                            color: Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }
                    }

                    Switch {
                        id: autoSwitch
                        Layout.alignment: Qt.AlignVCenter
                        checked: Prefs.weatherAuto
                        onToggled: Prefs.set("weatherAuto", autoSwitch.checked)
                    }
                }

                RowLayout { // ручной город
                    Layout.fillWidth: true
                    spacing: Theme.dp(8)

                    TextField {
                        id: cityField
                        Layout.fillWidth: true
                        enabled: !Prefs.weatherAuto
                        placeholder: "Например, Харьков"
                        text: Prefs.weatherCity
                        onAccepted: page.applyCity()
                    }

                    Button {
                        text: "Применить"
                        variant: "tonal"
                        disabled: !cityField.enabled || cityField.text.trim() === Prefs.weatherCity
                        onClicked: page.applyCity()
                    }
                }

                RowLayout { // текущее место
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dp(8)
                    spacing: Theme.dp(12)

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Theme.dp(40)
                        implicitHeight: Theme.dp(40)
                        radius: Theme.radiusPill
                        color: Theme.bgTrack

                        Icon {
                            anchors.centerIn: parent
                            name: "public"
                            size: Theme.dp(20)
                            color: Theme.subtext
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: Prefs.weatherPlace !== "" ? Prefs.weatherPlace : "Место не определено"
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyLarge")
                            font.weight: Theme.typeWeight("bodyLarge")
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: Weather.loading
                            text: "Обновление…"
                            color: Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: Weather.error !== ""
                            text: Weather.error
                            color: Theme.error
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        icon: "refresh"
                        disabled: Weather.loading
                        onClicked: Weather.refresh()
                    }
                }
            }
        }

        // 6. Композитор (окна, тени, анимации Umbriel)
        ColumnLayout {
            visible: page.section === 5
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Композитор"
                caption: "Окна, тени и анимации Umbriel — применяется сразу"
            }

            Card { // окна
                Layout.fillWidth: true
                title: "Окна"

                ParamRow {
                    label: "Зазор между окнами"
                    min: 0
                    max: 30
                    value: page.umbVal("layout.gap", 7)
                    displayMul: 1
                    suffix: ""
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "layout", "gap", Math.round(v))
                }
                ParamRow {
                    label: "Скругление окон"
                    min: 0
                    max: 40
                    value: page.umbVal("appearance.corner_radius", 18)
                    displayMul: 1
                    suffix: ""
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "appearance", "corner_radius", Math.round(v))
                }
                ParamRow {
                    label: "Толщина границы"
                    min: 0
                    max: 10
                    value: page.umbVal("appearance.border_width", 2)
                    displayMul: 1
                    suffix: ""
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "appearance", "border_width", Math.round(v))
                }
                ParamRow {
                    label: "Прозрачность при перетаскивании"
                    min: 30
                    max: 100
                    value: Math.round(page.umbVal("appearance.drag_opacity", 0.75) * 100)
                    displayMul: 1
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "appearance", "drag_opacity", v / 100)
                }
            }

            Card { // тени и анимации
                Layout.fillWidth: true
                title: "Тени и анимации"

                ToggleRow {
                    label: "Тени окон"
                    checked: page.umbVal("appearance.shadow.enabled", true)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "appearance.shadow", "enabled", v ? "true" : "false")
                }
                ParamRow {
                    label: "Мягкость тени"
                    min: 0
                    max: 100
                    value: page.umbVal("appearance.shadow.softness", 50)
                    displayMul: 1
                    suffix: ""
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "appearance.shadow", "softness", Math.round(v))
                }
                ToggleRow {
                    label: "Анимации окон"
                    checked: page.umbVal("animation.enabled", true)
                    onToggled: (v) => page.setUmb("src/general.toml", "animation", "enabled", v ? "true" : "false")
                }
            }

            Card { // эффекты
                Layout.fillWidth: true
                title: "Эффекты"

                ToggleRow {
                    label: "Размытие фона"
                    checked: page.umbVal("appearance.blur.enabled", true)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "appearance.blur", "enabled", v ? "true" : "false")
                }
            }
        }

        // 7. Ввод (мышь, клавиатура, фокус Umbriel)
        ColumnLayout {
            visible: page.section === 6
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Ввод"
                caption: "Мышь, клавиатура, фокус Umbriel"
            }

            Card { // мышь
                Layout.fillWidth: true
                title: "Мышь"

                ParamRow {
                    label: "Чувствительность"
                    min: -1
                    max: 1
                    value: page.umbVal("input.mouse.sensitivity", 0)
                    displayMul: 100
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.mouse", "sensitivity", Math.round(v * 100) / 100)
                }
                ToggleRow {
                    label: "Натуральная прокрутка"
                    checked: page.umbVal("input.mouse.natural_scroll", false)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.mouse", "natural_scroll", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Ускорение курсора"
                    values: ["flat", "adaptive"]
                    labels: ["Выключено", "Адаптивное"]
                    value: page.umbVal("input.mouse.accel_profile", "flat")
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.mouse", "accel_profile", "\"" + v + "\"")
                }
            }

            Card { // клавиатура
                Layout.fillWidth: true
                title: "Клавиатура"

                ParamRow {
                    label: "Задержка повтора"
                    min: 150
                    max: 1000
                    value: page.umbVal("input.keyboard.repeat_delay", 600)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.keyboard", "repeat_delay", Math.round(v))
                }
                ParamRow {
                    label: "Скорость повтора"
                    min: 10
                    max: 80
                    value: page.umbVal("input.keyboard.repeat_rate", 25)
                    displayMul: 1
                    suffix: " /с"
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.keyboard", "repeat_rate", Math.round(v))
                }
                ChoiceRow {
                    label: "Переключение раскладок"
                    values: ["grp:alt_shift_toggle", "grp:win_space_toggle", "grp:caps_toggle", "grp:ctrl_shift_toggle"]
                    labels: ["Alt+Shift", "Super+Space", "Caps Lock", "Ctrl+Shift"]
                    value: page.umbVal("input.keyboard.options", "grp:alt_shift_toggle")
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.keyboard", "options", "\"" + v + "\"")
                }
            }

            Card { // прочее
                Layout.fillWidth: true
                title: "Прочее"

                ToggleRow {
                    label: "Фокус следует за мышью"
                    checked: page.umbVal("input.focus.follows_mouse", true)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.focus", "follows_mouse", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Вставка средней кнопкой"
                    checked: page.umbVal("input.middle_click_paste", true)
                    onToggled: (v) => page.setUmb("src/input.toml", "input", "middle_click_paste", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Прятать курсор при печати"
                    checked: page.umbVal("input.cursor.hide_when_typing", false)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.cursor", "hide_when_typing", v ? "true" : "false")
                }
            }
        }

        // 8. Экран (монитор этого окна)
        ColumnLayout {
            visible: page.section === 7
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Экран"
                caption: "Монитор этого окна: " + page.outputName
            }

            Card {
                Layout.fillWidth: true
                title: page.outputName !== "" ? page.outputName : "Экран"

                ParamRow {
                    label: "Масштаб"
                    min: 75
                    max: 200
                    value: Math.round(page.umbVal("output." + page.outputName + ".scale", 1.0) * 100)
                    displayMul: 1
                    suffix: "%"
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        const rounded = Math.round(v / 5) * 5;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "scale", rounded / 100);
                    }
                }
                ChoiceRow {
                    id: freqRow
                    label: "Частота"
                    values: page.umbVal("output." + page.outputName + ".modes", [])
                    labels: page.umbVal("output." + page.outputName + ".modes", [])
                    value: page.umbVal("output." + page.outputName + ".mode", "")
                    visible: freqRow.values.length > 0
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "mode", "\"" + v + "\"");
                    }
                }
                ChoiceRow {
                    label: "VRR"
                    values: ["disabled", "always", "fullscreen"]
                    labels: ["Выключен", "Всегда", "В полный экран"]
                    value: page.umbVal("output." + page.outputName + ".vrr", "fullscreen")
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "vrr", "\"" + v + "\"");
                    }
                }
                ChoiceRow {
                    label: "Поворот"
                    values: ["normal", "90", "180", "270"]
                    labels: ["Обычный", "90°", "180°", "270°"]
                    value: page.umbVal("output." + page.outputName + ".transform", "normal")
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "transform", "\"" + v + "\"");
                    }
                }
            }
        }
    }

    // Switch и TextInput ломают биндинг при ручном изменении — синхронизируем
    // состояние обратно при записи в Prefs.
    Connections {
        target: Prefs

        function onWeatherAutoChanged() { autoSwitch.checked = Prefs.weatherAuto }
        function onWeatherCityChanged() { cityField.text = Prefs.weatherCity }
    }
}
