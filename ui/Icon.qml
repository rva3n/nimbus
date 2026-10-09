import QtQuick
import "../core"
import "Glyphs.js" as Glyphs

// Иконка Material Symbols Rounded из бандленного шрифта (~/nimbus/assets/fonts).
// name — имя символа: "wifi", "notifications", "power_settings_new", ...
Item {
    id: root

    property string name: ""
    property real size: 18
    property color color: Theme.subtext
    // у вариативного шрифта есть ось веса; 400 — обычный
    property int weight: 400

    implicitWidth: size
    implicitHeight: size

    readonly property int _cp: Glyphs.cp[root.name] !== undefined ? Glyphs.cp[root.name] : 0

    Text {
        anchors.fill: parent
        font.family: Theme.iconFont
        font.pixelSize: root.size
        font.weight: root.weight
        color: root.color
        text: root._cp > 0 ? String.fromCodePoint(root._cp) : ""
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
    }
}
