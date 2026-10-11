import QtQuick
import "../core"

// Текст на типографической шкале M3 (порт lucidui/LText.qml). role выбирает
// размер, вес и круглость терминалов вместе; tabular — моноширинные цифры.
Text {
    id: t

    property string role: "bodyMedium"
    property real weight: Theme.typeWeight(t.role)
    property real rounded: Theme.typeRound(t.role)
    property int size: Theme.typeSize(t.role)
    // фиксированная ширина цифр — для всего, что считает
    property bool tabular: false

    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: t.size
    font.weight: t.weight >= 650 ? Font.Bold : t.weight >= 540 ? Font.DemiBold : t.weight >= 470 ? Font.Medium : Font.Normal
    font.variableAxes: Theme.axes(t.size, t.weight, t.rounded)
    font.features: t.tabular ? ({ "tnum": 1 }) : ({})
    font.letterSpacing: t.role.indexOf("label") === 0 ? 0.2 : (t.role.indexOf("display") === 0 ? -0.4 : 0)
    verticalAlignment: Text.AlignVCenter
}
