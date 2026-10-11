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

    // мелкая приглушённая подпись-группа внутри карточки
    component GroupCaption: Text {
        Layout.fillWidth: true
        Layout.topMargin: Theme.dp(6)
        color: Theme.subtextDim
        elide: Text.ElideRight
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelMedium")
        font.weight: Theme.typeWeight("labelMedium")
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

        // 6. Композитор (окна, раскладка, анимации, эффекты)
        ColumnLayout {
            visible: page.section === 5
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Композитор"
                caption: "Окна, раскладка, анимации и эффекты Umbriel — применяется сразу"
            }

            Card { // окна
                Layout.fillWidth: true
                title: "Окна"

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
                ToggleRow {
                    label: "Непрозрачный фуллскрин"
                    checked: page.umbVal("appearance.opaque_fullscreen", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "appearance", "opaque_fullscreen", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Режим раскладки"
                    values: ["scrolling", "dwindle", "master"]
                    labels: ["Прокрутка", "Двоичное", "Мастер"]
                    value: page.umbVal("layout.mode", "dwindle")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "layout", "mode", "\"" + v + "\"")
                }
            }

            Card { // раскладка
                Layout.fillWidth: true
                title: "Раскладка"

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
                    label: "Доля прокрутки по умолчанию"
                    min: 0.1
                    max: 1.0
                    value: page.umbVal("layout.scrolling.default_extent_fraction", 0.5)
                    displayMul: 100
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "layout.scrolling", "default_extent_fraction", Math.round(v * 100) / 100)
                }
                ChoiceRow {
                    label: "Центрирование активного"
                    values: ["never", "always", "on_overflow"]
                    labels: ["Никогда", "Всегда", "При переполнении"]
                    value: page.umbVal("layout.scrolling.center_focused", "never")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "layout.scrolling", "center_focused", "\"" + v + "\"")
                }
                ToggleRow {
                    label: "Центрировать неполную полосу"
                    checked: page.umbVal("layout.scrolling.center_underfull_strip", true)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "layout.scrolling", "center_underfull_strip", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Новые окна выходят из фуллскрина"
                    checked: page.umbVal("layout.new_exits_fullscreen", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "layout", "new_exits_fullscreen", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Двоичное: новые к курсору"
                    checked: page.umbVal("layout.dwindle.new_toward_cursor", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "layout.dwindle", "new_toward_cursor", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Двоичное: сохранять разделение"
                    checked: page.umbVal("layout.dwindle.preserve_split", true)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "layout.dwindle", "preserve_split", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Мастер: положение"
                    values: ["left", "right", "center"]
                    labels: ["Слева", "Справа", "По центру"]
                    value: page.umbVal("layout.master.position", "left")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "layout.master", "position", "\"" + v + "\"")
                }
                ParamRow {
                    label: "Мастер: доля ширины"
                    min: 0.1
                    max: 0.9
                    value: page.umbVal("layout.master.default_width_fraction", 0.55)
                    displayMul: 100
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "layout.master", "default_width_fraction", Math.round(v * 100) / 100)
                }
                ToggleRow {
                    label: "Мастер: новые сверху"
                    checked: page.umbVal("layout.master.new_on_top", true)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "layout.master", "new_on_top", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Мастер: новые становятся мастером"
                    checked: page.umbVal("layout.master.new_becomes_master", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "layout.master", "new_becomes_master", v ? "true" : "false")
                }
            }

            Card { // тени
                Layout.fillWidth: true
                title: "Тени"

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
            }

            Card { // анимации
                Layout.fillWidth: true
                title: "Анимации"

                ToggleRow {
                    label: "Анимации окон"
                    checked: page.umbVal("animation.enabled", true)
                    onToggled: (v) => page.setUmb("src/general.toml", "animation", "enabled", v ? "true" : "false")
                }

                GroupCaption { text: "Окна (открытие)" }
                ParamRow {
                    label: "Длительность"
                    min: 50
                    max: 1000
                    value: page.umbVal("animation.windows_in.duration_ms", 220)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.windows_in", "duration_ms", Math.round(v))
                }
                ChoiceRow {
                    label: "Стиль"
                    values: ["popin", "zoom", "slide", "fade", "none"]
                    labels: ["Popin", "Zoom", "Slide", "Fade", "Нет"]
                    value: page.umbVal("animation.windows_in.style", "popin")
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.windows_in", "style", "\"" + v + "\"")
                }

                GroupCaption { text: "Окна (закрытие)" }
                ParamRow {
                    label: "Длительность"
                    min: 50
                    max: 1000
                    value: page.umbVal("animation.windows_out.duration_ms", 180)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.windows_out", "duration_ms", Math.round(v))
                }
                ChoiceRow {
                    label: "Стиль"
                    values: ["fade", "slide", "popin", "zoom"]
                    labels: ["Fade", "Slide", "Popin", "Zoom"]
                    value: page.umbVal("animation.windows_out.style", "fade")
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.windows_out", "style", "\"" + v + "\"")
                }

                GroupCaption { text: "Окна (перемещение)" }
                ParamRow {
                    label: "Длительность"
                    min: 50
                    max: 1000
                    value: page.umbVal("animation.windows_move.duration_ms", 250)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.windows_move", "duration_ms", Math.round(v))
                }

                GroupCaption { text: "Рабочие пространства" }
                ParamRow {
                    label: "Длительность"
                    min: 50
                    max: 1000
                    value: page.umbVal("animation.workspaces.duration_ms", 300)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.workspaces", "duration_ms", Math.round(v))
                }
                ChoiceRow {
                    label: "Стиль"
                    values: ["slide", "reveal"]
                    labels: ["Slide", "Reveal"]
                    value: page.umbVal("animation.workspaces.style", "slide")
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.workspaces", "style", "\"" + v + "\"")
                }

                GroupCaption { text: "Граница" }
                ParamRow {
                    label: "Длительность"
                    min: 50
                    max: 1000
                    value: page.umbVal("animation.border.duration_ms", 180)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.border", "duration_ms", Math.round(v))
                }

                GroupCaption { text: "Затемнение неактивных" }
                ToggleRow {
                    label: "Затемнять неактивные окна"
                    checked: page.umbVal("animation.dim_unfocused.enabled", true)
                    onToggled: (v) => page.setUmb("src/general.toml", "animation.dim_unfocused", "enabled", v ? "true" : "false")
                }
                ParamRow {
                    label: "Затемнение"
                    min: 0
                    max: 1
                    value: page.umbVal("animation.dim_unfocused.dim", 0.12)
                    displayMul: 100
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.dim_unfocused", "dim", Math.round(v * 100) / 100)
                }

                GroupCaption { text: "Scratchpad" }
                ToggleRow {
                    label: "Анимация scratchpad"
                    checked: page.umbVal("animation.scratchpad.enabled", false)
                    onToggled: (v) => page.setUmb("src/general.toml", "animation.scratchpad", "enabled", v ? "true" : "false")
                }
                ParamRow {
                    label: "Затемнение"
                    min: 0
                    max: 1
                    value: page.umbVal("animation.scratchpad.dim", 0.5)
                    displayMul: 100
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.scratchpad", "dim", Math.round(v * 100) / 100)
                }
                ToggleRow {
                    label: "Размытие"
                    checked: page.umbVal("animation.scratchpad.blur", true)
                    onToggled: (v) => page.setUmb("src/general.toml", "animation.scratchpad", "blur", v ? "true" : "false")
                }
                ParamRow {
                    label: "Масштаб"
                    min: 0
                    max: 1
                    value: page.umbVal("animation.scratchpad.scale", 0.0)
                    displayMul: 100
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/general.toml", "animation.scratchpad", "scale", Math.round(v * 100) / 100)
                }

                GroupCaption { text: "Перетаскивание" }
                ToggleRow {
                    label: "Физика перетаскивания окон"
                    checked: page.umbVal("animation.windows_drag.physics", true)
                    onToggled: (v) => page.setUmb("src/general.toml", "animation.windows_drag", "physics", v ? "true" : "false")
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
                ChoiceRow {
                    label: "Граница"
                    values: ["", "off", "pulse", "audio"]
                    labels: ["Выключено", "Выключено", "Pulse", "Audio"]
                    value: page.umbVal("effects.border", "")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "effects", "border", "\"" + v + "\"")
                }
                ChoiceRow {
                    label: "Окно"
                    values: ["", "off", "scanlines"]
                    labels: ["Выключено", "Выключено", "Сканлайны"]
                    value: page.umbVal("effects.window", "")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "effects", "window", "\"" + v + "\"")
                }
                ChoiceRow {
                    label: "Экран"
                    values: ["", "off", "vignette"]
                    labels: ["Выключено", "Выключено", "Виньетка"]
                    value: page.umbVal("effects.screen", "")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "effects", "screen", "\"" + v + "\"")
                }
                ChoiceRow {
                    label: "Курсор"
                    values: ["", "off", "glow", "trail", "trail-path"]
                    labels: ["Выключено", "Выключено", "Свечение", "Шлейф", "Шлейф-путь"]
                    value: page.umbVal("effects.cursor", "")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "effects", "cursor", "\"" + v + "\"")
                }
                ParamRow {
                    label: "Максимум FPS эффектов"
                    min: 0
                    max: 240
                    value: page.umbVal("effects.max_fps", 60)
                    displayMul: 1
                    suffix: " fps"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "effects", "max_fps", Math.round(v))
                }
            }

            Card { // рабочие пространства
                Layout.fillWidth: true
                title: "Рабочие пространства"

                ToggleRow {
                    label: "Переключение туда-обратно"
                    checked: page.umbVal("workspaces.back_and_forth", false)
                    onToggled: (v) => page.setUmb("src/general.toml", "workspaces", "back_and_forth", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Пустое пространство сверху"
                    checked: page.umbVal("workspaces.empty_above", false)
                    onToggled: (v) => page.setUmb("src/general.toml", "workspaces", "empty_above", v ? "true" : "false")
                }
                ParamRow {
                    label: "Масштаб обзора"
                    min: 0.1
                    max: 0.75
                    value: page.umbVal("overview.zoom", 0.4)
                    displayMul: 100
                    suffix: "%"
                    onCommitted: (v) => page.setUmb("src/general.toml", "overview", "zoom", Math.round(v * 100) / 100)
                }
                ToggleRow {
                    label: "Размытие фона обзора"
                    checked: page.umbVal("overview.background_blur", true)
                    onToggled: (v) => page.setUmb("src/general.toml", "overview", "background_blur", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Обои рабочего пространства"
                    checked: page.umbVal("overview.workspace_wallpaper", false)
                    onToggled: (v) => page.setUmb("src/general.toml", "overview", "workspace_wallpaper", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Подсказки обзора"
                    checked: page.umbVal("overview.shortcuts", true)
                    onToggled: (v) => page.setUmb("src/general.toml", "overview", "shortcuts", v ? "true" : "false")
                }
            }

            Card { // горячие углы
                Layout.fillWidth: true
                title: "Горячие углы"

                GroupCaption { text: "Левый верхний" }
                ToggleRow {
                    label: "Включён"
                    checked: page.umbVal("hot_corners.top_left.enabled", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "hot_corners.top_left", "enabled", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Действие"
                    values: ["overview-open", "overview-close", "overview-toggle"]
                    labels: ["Обзор", "Закрыть обзор", "Переключить обзор"]
                    value: page.umbVal("hot_corners.top_left.action", "overview-open")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.top_left", "action", "\"" + v + "\"")
                }
                ParamRow {
                    label: "Задержка"
                    min: 0
                    max: 2000
                    value: page.umbVal("hot_corners.top_left.delay_ms", 500)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.top_left", "delay_ms", Math.round(v))
                }

                GroupCaption { text: "Правый верхний" }
                ToggleRow {
                    label: "Включён"
                    checked: page.umbVal("hot_corners.top_right.enabled", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "hot_corners.top_right", "enabled", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Действие"
                    values: ["overview-open", "overview-close", "overview-toggle"]
                    labels: ["Обзор", "Закрыть обзор", "Переключить обзор"]
                    value: page.umbVal("hot_corners.top_right.action", "overview-open")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.top_right", "action", "\"" + v + "\"")
                }
                ParamRow {
                    label: "Задержка"
                    min: 0
                    max: 2000
                    value: page.umbVal("hot_corners.top_right.delay_ms", 500)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.top_right", "delay_ms", Math.round(v))
                }

                GroupCaption { text: "Левый нижний" }
                ToggleRow {
                    label: "Включён"
                    checked: page.umbVal("hot_corners.bottom_left.enabled", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "hot_corners.bottom_left", "enabled", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Действие"
                    values: ["overview-open", "overview-close", "overview-toggle"]
                    labels: ["Обзор", "Закрыть обзор", "Переключить обзор"]
                    value: page.umbVal("hot_corners.bottom_left.action", "overview-open")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.bottom_left", "action", "\"" + v + "\"")
                }
                ParamRow {
                    label: "Задержка"
                    min: 0
                    max: 2000
                    value: page.umbVal("hot_corners.bottom_left.delay_ms", 500)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.bottom_left", "delay_ms", Math.round(v))
                }

                GroupCaption { text: "Правый нижний" }
                ToggleRow {
                    label: "Включён"
                    checked: page.umbVal("hot_corners.bottom_right.enabled", false)
                    onToggled: (v) => page.setUmb("src/appearance.toml", "hot_corners.bottom_right", "enabled", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Действие"
                    values: ["overview-open", "overview-close", "overview-toggle"]
                    labels: ["Обзор", "Закрыть обзор", "Переключить обзор"]
                    value: page.umbVal("hot_corners.bottom_right.action", "overview-open")
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.bottom_right", "action", "\"" + v + "\"")
                }
                ParamRow {
                    label: "Задержка"
                    min: 0
                    max: 2000
                    value: page.umbVal("hot_corners.bottom_right.delay_ms", 500)
                    displayMul: 1
                    suffix: " мс"
                    onCommitted: (v) => page.setUmb("src/appearance.toml", "hot_corners.bottom_right", "delay_ms", Math.round(v))
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
                ToggleRow {
                    label: "Левша"
                    checked: page.umbVal("input.mouse.left_handed", false)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.mouse", "left_handed", v ? "true" : "false")
                }
                ParamRow {
                    label: "Шаг колеса прокрутки"
                    min: 10
                    max: 200
                    value: page.umbVal("input.mouse.scroll_wheel_step", 60)
                    displayMul: 1
                    suffix: ""
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.mouse", "scroll_wheel_step", Math.round(v))
                }
                ToggleRow {
                    label: "Перетаскивание за клиентскую область"
                    checked: page.umbVal("input.client_window_drag", false)
                    onToggled: (v) => page.setUmb("src/input.toml", "input", "client_window_drag", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Перетаскивание переключает"
                    values: ["none", "floating", "pinned"]
                    labels: ["Ничего", "Плавающие", "Закреплённые"]
                    value: page.umbVal("input.window_drag_toggle", "none")
                    onCommitted: (v) => page.setUmb("src/input.toml", "input", "window_drag_toggle", "\"" + v + "\"")
                }
            }

            Card { // тачпад
                Layout.fillWidth: true
                title: "Тачпад"

                ToggleRow {
                    label: "Тап"
                    checked: page.umbVal("input.touchpad.tap", true)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.touchpad", "tap", v ? "true" : "false")
                }
                ChoiceRow {
                    label: "Кнопки при тапе"
                    values: ["left_right_middle", "left_middle_right"]
                    labels: ["ЛКМ-ПКМ-СКМ", "ЛКМ-СКМ-ПКМ"]
                    value: page.umbVal("input.touchpad.tap_button_map", "left_right_middle")
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.touchpad", "tap_button_map", "\"" + v + "\"")
                }
                ChoiceRow {
                    label: "Метод нажатия"
                    values: ["button_areas", "clickfinger"]
                    labels: ["Кнопки", "Отпечаток"]
                    value: page.umbVal("input.touchpad.click_method", "button_areas")
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.touchpad", "click_method", "\"" + v + "\"")
                }
                ToggleRow {
                    label: "Левша"
                    checked: page.umbVal("input.touchpad.left_handed", false)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.touchpad", "left_handed", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Натуральная прокрутка"
                    checked: page.umbVal("input.touchpad.natural_scroll", true)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.touchpad", "natural_scroll", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Отключать при печати"
                    checked: page.umbVal("input.touchpad.disable_while_typing", true)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.touchpad", "disable_while_typing", v ? "true" : "false")
                }
                ToggleRow {
                    label: "Отключать при внешней мыши"
                    checked: page.umbVal("input.touchpad.disable_on_external_mouse", false)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.touchpad", "disable_on_external_mouse", v ? "true" : "false")
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

            Card { // фокус
                Layout.fillWidth: true
                title: "Фокус"

                ToggleRow {
                    label: "Фокус следует за мышью"
                    checked: page.umbVal("input.focus.follows_mouse", true)
                    onToggled: (v) => page.setUmb("src/input.toml", "input.focus", "follows_mouse", v ? "true" : "false")
                }
                ParamRow {
                    label: "Максимум прокрутки при следовании"
                    min: 0
                    max: 100
                    value: page.umbVal("input.focus.follows_mouse_max_scroll", 0)
                    displayMul: 1
                    suffix: ""
                    onCommitted: (v) => page.setUmb("src/input.toml", "input.focus", "follows_mouse_max_scroll", Math.round(v))
                }
            }

            Card { // прочее
                Layout.fillWidth: true
                title: "Прочее"

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
                ToggleRow {
                    label: "Циклические рабочие пространства"
                    checked: page.umbVal("output." + page.outputName + ".cyclic_workspaces", true)
                    onToggled: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "cyclic_workspaces", v ? "true" : "false");
                    }
                }
                ChoiceRow {
                    label: "Ось рабочих пространств"
                    values: ["vertical", "horizontal"]
                    labels: ["Вертикально", "Горизонтально"]
                    value: page.umbVal("output." + page.outputName + ".workspace_axis", "vertical")
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "workspace_axis", "\"" + v + "\"");
                    }
                }
                ParamRow {
                    label: "Минимум рабочих пространств"
                    min: 1
                    max: 10
                    value: page.umbVal("output." + page.outputName + ".min_workspaces", 1)
                    displayMul: 1
                    suffix: ""
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "min_workspaces", Math.round(v));
                    }
                }
                ChoiceRow {
                    label: "HDR"
                    values: ["off", "on", "auto", "fullscreen"]
                    labels: ["Выкл", "Вкл", "Авто", "В полный экран"]
                    value: page.umbVal("output." + page.outputName + ".hdr", "off")
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "hdr", "\"" + v + "\"");
                    }
                }
                ChoiceRow {
                    label: "Глубина цвета"
                    values: [8, 10]
                    labels: ["8 бит", "10 бит"]
                    value: page.umbVal("output." + page.outputName + ".bit_depth", 8)
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "bit_depth", v);
                    }
                }
                ParamRow {
                    label: "Яркость SDR-белого"
                    min: 80
                    max: 1000
                    value: page.umbVal("output." + page.outputName + ".sdr_white", 203)
                    displayMul: 1
                    suffix: " кд/м²"
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "sdr_white", Math.round(v));
                    }
                }
                ToggleRow {
                    label: "Прямой вывод (direct scanout)"
                    checked: page.umbVal("output." + page.outputName + ".direct_scanout", false)
                    onToggled: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "direct_scanout", v ? "true" : "false");
                    }
                }
                ToggleRow {
                    label: "Разрывы (tearing)"
                    checked: page.umbVal("output." + page.outputName + ".tearing", false)
                    onToggled: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "tearing", v ? "true" : "false");
                    }
                }
                ChoiceRow {
                    label: "Экранный эффект"
                    values: ["", "off", "vignette"]
                    labels: ["Выключено", "Выключено", "Виньетка"]
                    value: page.umbVal("output." + page.outputName + ".screen_effect", "")
                    onCommitted: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "screen_effect", "\"" + v + "\"");
                    }
                }
                ToggleRow {
                    label: "Фокус при запуске"
                    checked: page.umbVal("output." + page.outputName + ".focus_at_startup", true)
                    onToggled: (v) => {
                        if (page.outputName === "") return;
                        page.setUmb("src/appearance.toml", "output:" + page.outputName, "focus_at_startup", v ? "true" : "false");
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
