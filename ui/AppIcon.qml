import QtQuick
import Quickshell
import Quickshell.Widgets
import "../core"

// Иконка приложения: резолвится системной темой иконок (см. прагму
// IconTheme в shell.qml) и рисуется в натуральном цвете — без перекраски.
//   AppIcon { source: path; size: Theme.dp(24) }
// radius > 0 — обрезка по кругу (radius = size/2).
Item {
    id: icon

    property string source: ""
    property real size: Theme.dp(24) // отображаемая сторона, px
    property real radius: 0  // радиус обрезки; 0 = без обрезки

    // Голые имена (например, хинты уведомлений) резолвим системной темой
    // иконок; пути и URL проходят как есть.
    readonly property string _resolved: {
        if (icon.source === "")
            return "";

        if (icon.source.indexOf("/") !== -1 || icon.source.indexOf(":") !== -1)
            return icon.source;

        return Quickshell.iconPath(icon.source, true) || "";
    }

    implicitWidth: size
    implicitHeight: size

    // Обрезка по кругу через ClippingRectangle
    ClippingRectangle {
        anchors.fill: parent
        visible: icon.radius > 0
        color: "transparent"
        radius: icon.radius

        Image {
            anchors.fill: parent
            source: icon._resolved
            sourceSize.width: Math.max(8, Math.round(width * 2))
            sourceSize.height: Math.max(8, Math.round(height * 2))
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // Без обрезки
    Image {
        anchors.fill: parent
        source: icon._resolved
        sourceSize.width: Math.max(8, Math.round(width * 2))
        sourceSize.height: Math.max(8, Math.round(height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: icon.radius <= 0
    }
}
