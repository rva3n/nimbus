import QtQuick
import QtQuick.Effects
import "../core"

// Иконка приложения, окрашиваемая по палитре matugen (моно-tint):
// силуэт сохраняется, цвет берётся из темы (MultiEffect-колоризация —
// тот же приём, что у трай-иконок в Lucid).
//   AppIcon { source: path; tint: Theme.subtext; size: 13 }
Item {
    id: root

    property string source: ""
    property color tint: Theme.subtext
    property bool tinted: true
    property real size: 13   // сторона, dp

    implicitWidth: Theme.dp(size)
    implicitHeight: Theme.dp(size)

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.max(8, Math.round(width * 2))
        sourceSize.height: Math.max(8, Math.round(height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        layer.enabled: root.tinted
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.tint
        }
    }
}
