import QtQuick
import "../core"

// Маленький бейдж Oberon (порт lucidui/Badge.qml): точка 6dp, счётчик-пилюля
// 16dp (или произвольная текст-пилюля). Цифры стоят на базовой линии, поэтому
// строку центрируем по чернилам цифр через метрики Theme.
// tone: accent | error | neutral; count<0 и пустой text — точка.
Rectangle {
    id: badge

    property string text: ""
    property string tone: "accent"
    property int count: -1
    property int max: 99
    // цветовой override (пустой = вывести из tone)
    property color toneColor: "transparent"
    property color fg: "transparent"

    readonly property bool dot: badge.count < 0 && badge.text === ""
    readonly property bool numeric: badge.count >= 0
    readonly property color _bg: badge.toneColor.a > 0 ? badge.toneColor : (badge.tone === "error" ? Theme.errorContainer : (badge.tone === "neutral" ? Theme.bgTrack : Theme.accent))
    readonly property color _fg: badge.fg.a > 0 ? badge.fg : (badge.tone === "error" ? Theme.fgErrorContainer : (badge.tone === "neutral" ? Theme.subtext : Theme.fgOnFill))
    // метрики цифр из Theme — приводим коррекцию центра к размеру счётчика
    readonly property real _numSize: Theme.fs(10.5)

    implicitWidth: badge.dot ? Theme.dp(6) : (badge.numeric ? Math.max(Theme.dp(16), num.implicitWidth + Theme.dp(8)) : label.implicitWidth + Theme.dp(8) * 2)
    implicitHeight: badge.dot ? Theme.dp(6) : (badge.numeric ? Theme.dp(16) : Theme.dp(20))
    radius: height / 2
    color: badge._bg

    LText {
        id: num

        visible: badge.numeric
        anchors.centerIn: parent
        // вертикально — по центру чернил цифры, а не строчного бокса
        anchors.verticalCenterOffset: Theme.digitCenterOffset * badge._numSize
        role: "labelSmall"
        weight: 650
        size: badge._numSize
        color: badge._fg
        text: badge.count > badge.max ? badge.max + "+" : String(badge.count)
    }

    LText {
        id: label

        visible: !badge.dot && !badge.numeric
        anchors.centerIn: parent
        role: "labelSmall"
        size: Theme.fs(10)
        color: badge._fg
        text: badge.text
    }

}
