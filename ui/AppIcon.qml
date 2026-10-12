import QtQuick
import Quickshell
import "../core"

// Иконка приложения: резолвится системной темой иконок (см. прагму
// IconTheme в shell.qml) и рисуется в натуральном цвете — без перекраски.
//   AppIcon { source: path; size: 13 }
Item {
    id: root

    property string source: ""
    property real size: 13   // сторона, dp

    // Голые имена (например, хинты уведомлений) резолвим системной темой
    // иконок; пути и URL проходят как есть.
    readonly property string _resolved: {
        if (root.source === "")
            return "";

        if (root.source.indexOf("/") !== -1 || root.source.indexOf(":") !== -1)
            return root.source;

        return Quickshell.iconPath(root.source, true) || "";
    }

    implicitWidth: Theme.dp(size)
    implicitHeight: Theme.dp(size)

    Image {
        anchors.fill: parent
        source: root._resolved
        sourceSize.width: Math.max(8, Math.round(width * 2))
        sourceSize.height: Math.max(8, Math.round(height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
