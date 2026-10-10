import QtQuick
import QtQuick.Layouts
import Quickshell
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
    // выбранный раздел: 0 — интерфейс, 1 — погода, 2 — о шелле, 3 — сброс
    property int section: 0

    visible: win !== null && win.mode === "panel" && win.page === "settings"
    Layout.fillWidth: true
    spacing: Theme.dp(16)

    // при каждом открытии страницы — первый раздел
    onVisibleChanged: if (visible) page.section = 0

    function applyCity() {
        Prefs.set("weatherCity", cityField.text.trim());
    }

    function resetPrefs() {
        Prefs.set("uiScale", 1);
        Prefs.set("cornerScale", 1);
        Prefs.set("motionScale", 1);
        Prefs.set("accentPunch", 1);
        Prefs.set("surfaceDarkness", -1);
        Prefs.set("surfaceTint", -1);
        Prefs.set("blurAmount", 45);
        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/nimbus/scripts/set-blur.sh", "45"]);
        Prefs.set("weatherAuto", true);
        Prefs.set("weatherCity", "");
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

    // строка-инфо: иконка 40×40 на подложке, подпись слева, значение справа
    component InfoRow: RowLayout {
        id: ir

        property string icon: "info"
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.topMargin: Theme.dp(6)
        Layout.bottomMargin: Theme.dp(6)
        spacing: Theme.dp(12)

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusPill
            color: Theme.bgTrack

            Icon {
                anchors.centerIn: parent
                name: ir.icon
                size: Theme.dp(20)
                color: Theme.subtext
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: ir.label
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyLarge")
            font.weight: Theme.typeWeight("bodyLarge")
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: ir.value
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
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
            label: "Интерфейс"
            selected: page.section === 0
            onClicked: page.section = 0
        }
        NavItem {
            icon: "sunny"
            label: "Погода"
            selected: page.section === 1
            onClicked: page.section = 1
        }
        NavItem {
            icon: "info"
            label: "О шелле"
            selected: page.section === 2
            onClicked: page.section = 2
        }
        NavItem {
            icon: "restart_alt"
            label: "Сброс"
            selected: page.section === 3
            onClicked: page.section = 3
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
                title: "Интерфейс"
                caption: "Размер, форма и движение элементов"
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

                Text { // пояснение к ползунку размытия
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dp(2)
                    text: "Интенсивность размытия фона (радиус Umbriel; влияет и на окна). Прозрачность фиксированная; всегда есть лёгкий мороз."
                    color: Theme.subtextDim
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }

        // 2. Погода
        ColumnLayout {
            visible: page.section === 1
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

                Divider { // место — отдельно от ввода города
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dp(4)
                    leftInset: Theme.dp(56)
                }

                RowLayout { // текущее место
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.dp(4)
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

        // 3. О шелле
        ColumnLayout {
            visible: page.section === 2
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "О шелле"
                caption: "Сборка, композитор и конфиг"
            }

            Card {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    InfoRow {
                        icon: "info"
                        label: "Nimbus"
                        value: "2.0"
                    }
                    Divider {
                        Layout.fillWidth: true
                        leftInset: Theme.dp(56)
                    }
                    InfoRow {
                        icon: "monitor"
                        label: "Композитор"
                        value: "Umbriel"
                    }
                    Divider {
                        Layout.fillWidth: true
                        leftInset: Theme.dp(56)
                    }
                    InfoRow {
                        icon: "folder"
                        label: "Конфиг"
                        value: "~/nimbus"
                    }
                    Divider {
                        Layout.fillWidth: true
                        leftInset: Theme.dp(56)
                    }
                    InfoRow {
                        icon: "description"
                        label: "Лицензия"
                        value: "MIT"
                    }
                }
            }
        }

        // 4. Сброс
        ColumnLayout {
            visible: page.section === 3
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            SectionHeader {
                title: "Сброс"
                caption: "Значения по умолчанию"
            }

            Card {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Вернуть внешний вид и погоду к значениям по умолчанию."
                    color: Theme.subtext
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }

                Button {
                    Layout.topMargin: Theme.dp(4)
                    text: "Сбросить настройки"
                    icon: "restart_alt"
                    variant: "tonal"
                    onClicked: page.resetPrefs()
                }
            }
        }
    }

    // Switch и TextInput ломают биндинг при ручном изменении — синхронизируем
    // состояние обратно при записи в Prefs (в т.ч. после сброса).
    Connections {
        target: Prefs

        function onWeatherAutoChanged() { autoSwitch.checked = Prefs.weatherAuto }
        function onWeatherCityChanged() { cityField.text = Prefs.weatherCity }
    }
}
