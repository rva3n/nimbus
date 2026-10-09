import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Настройки»: внешний вид (пишет в Prefs → ~/nimbus/prefs.json),
// погода (авто по IP или город) и сброс к значениям по умолчанию.
ColumnLayout {
    id: page

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "settings"
    Layout.fillWidth: true
    spacing: Theme.dp(10)

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
        Prefs.set("blurAmount", 0);
        Prefs.set("weatherAuto", true);
        Prefs.set("weatherCity", "");
    }

    // строка параметра: подпись + значение, ниже слайдер 0..1 (min..max)
    component ParamRow: ColumnLayout {
        id: pr

        property string label: ""
        property real min: 0
        property real max: 1
        property real value: 1

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
                text: Math.round(pr.value * 100) + "%"
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

    Card { // ── внешний вид
        Layout.fillWidth: true
        title: "Внешний вид"

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

        Text { // blurAmount не выводим: в Umbriel блюра слоёв нет
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            text: "Размытие слоёв недоступно в Umbriel — параметр скрыт."
            color: Theme.subtextDim
            wrapMode: Text.WordWrap
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }
    }

    Card { // ── погода
        Layout.fillWidth: true
        title: "Погода"
        actionIcon: "refresh"
        onActionClicked: Weather.refresh()

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
            Layout.topMargin: Theme.dp(4)
            spacing: Theme.dp(12)

            Rectangle {
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
                icon: "refresh"
                disabled: Weather.loading
                onClicked: Weather.refresh()
            }
        }
    }

    Card { // ── сброс
        Layout.fillWidth: true
        title: "Сброс"

        Text {
            Layout.fillWidth: true
            text: "Вернуть внешний вид и погоду к значениям по умолчанию."
            color: Theme.subtext
            wrapMode: Text.WordWrap
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }

        Button {
            Layout.topMargin: Theme.dp(4)
            text: "Сбросить настройки"
            icon: "restart_alt"
            variant: "tonal"
            onClicked: page.resetPrefs()
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
