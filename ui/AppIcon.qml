import QtQuick
import QtQuick.Shapes
import Quickshell
import "../core"

// Иконка приложения: резолвится системной темой иконок (см. прагму
// IconTheme в shell.qml) и рисуется в натуральном цвете — без перекраски.
//   AppIcon { source: path; size: Theme.dp(24) }
// radius > 0 — обрезка по кругу (radius = size/2).
Item {
    id: root

    property string source: ""
    property real size: Theme.dp(24) // отображаемая сторона, px
    property real radius: 0  // радиус обрезки; 0 = без обрезки

    // Голые имена (например, хинты уведомлений) резолвим системной темой
    // иконок; пути и URL проходят как есть.
    readonly property string _resolved: {
        if (root.source === "")
            return "";

        if (root.source.indexOf("/") !== -1 || root.source.indexOf(":") !== -1)
            return root.source;

        return Quickshell.iconPath(root.source, true) || "";
    }

    implicitWidth: size
    implicitHeight: size

    // Обрезка по кругу через Shape с clip
    Shape {
        anchors.fill: parent
        visible: root.radius > 0
        clip: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeWidth: 0
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        Image {
            anchors.fill: parent
            source: root._resolved
            sourceSize.width: Math.max(8, Math.round(width * 2))
            sourceSize.height: Math.max(8, Math.round(height * 2))
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // Без обрезки
    Image {
        anchors.fill: parent
        source: root._resolved
        sourceSize.width: Math.max(8, Math.round(width * 2))
        sourceSize.height: Math.max(8, Math.round(height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: root.radius <= 0
    }
}
