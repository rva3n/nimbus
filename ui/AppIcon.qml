import QtQuick
import "../core"

// Иконка приложения: резолвится системной темой иконок (см. прагму
// IconTheme в shell.qml) и рисуется в натуральном цвете — без перекраски.
//   AppIcon { source: path; size: 13 }
Item {
    id: root

    property string source: ""
    property real size: 13   // сторона, dp

    implicitWidth: Theme.dp(size)
    implicitHeight: Theme.dp(size)

    Image {
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.max(8, Math.round(width * 2))
        sourceSize.height: Math.max(8, Math.round(height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
