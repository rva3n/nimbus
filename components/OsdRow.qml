import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// OSD-строка (volume/brightness) внутри капсулы острова. Анатомия 1:1 из
// lucidosd/Osd.qml: глиф уровня живёт в отдельном бейдже (не внутри трека),
// слайдер уровня — трек dp(30)/ручка dp(38) с подписью на заливке.
// API прежний (kind/value/muted), саму капсулу рисует Island.
RowLayout {
    id: osdRow
    property string kind: "volume"
    property real value: 0
    property bool muted: false
    spacing: Theme.dp(10)

    readonly property bool isVolume: osdRow.kind === "volume"
    // mute относится только к громкости: у яркости «выключения» нет
    readonly property bool silent: osdRow.isVolume && osdRow.muted
    readonly property real pct: Math.max(0, Math.min(1, osdRow.value)) * 100

    // уровневые иконки — levelIcon из lucidosd/Osd.qml (per-value)
    readonly property string levelIcon: {
        if (osdRow.kind === "brightness")
            return osdRow.value < 0.34 ? "brightness_low" : (osdRow.value < 0.67 ? "brightness_medium" : "brightness_high");

        if (osdRow.muted || osdRow.value <= 0)
            return "volume_off";

        return osdRow.value < 0.34 ? "volume_mute" : (osdRow.value < 0.67 ? "volume_down" : "volume_up");
    }

    // появление: pop OutBack с overshoot темы (cardPop из Lucid). Скрытие
    // делает капсула острова (S1).
    scale: 0.9
    onVisibleChanged: {
        if (visible)
            popIn.restart();
        else
            scale = 0.9;
    }

    NumberAnimation {
        id: popIn
        target: osdRow
        property: "scale"
        to: 1
        duration: Theme.durEnter
        easing.type: Easing.OutBack
        easing.overshoot: Theme.emphasizedOvershoot
    }

    Slider {
        Layout.alignment: Qt.AlignVCenter
        // ширина карточки уровня из Lucid (dp(260)); бейдж внутри
        Layout.preferredWidth: Theme.dp(260)
        size: "m"
        // метрики уровневого слайдера lucidosd/Osd.qml
        trackH: Theme.dp(30)
        handleH: Theme.dp(38)
        outerR: Theme.dp(30) / 2
        iconSize: Theme.dp(18)
        // иконка — ведущий бейдж-глиф, а не внутри трека
        icon: osdRow.levelIcon
        from: 0
        to: 100
        value: osdRow.silent ? 0 : osdRow.pct
        showValue: false
        inlineValue: true
        valueText: (v) => osdRow.silent ? "mute" : Math.round(v) + "%"
        activeColor: osdRow.silent ? Theme.outlineStrong : Theme.primary
        inactiveColor: Theme.mHighest
        easeValue: true
        // OSD только показывает уровень (значение задаёт Osd) — драг не нужен
        enabled: false
        opacity: 1
    }
}
