import QtQuick
import "../core"

// Горизонтальный разделитель M3: линия 1px с отступами по краям.
Item {
    id: root

    property real leftInset: 0
    property real rightInset: 0

    implicitWidth: Theme.dp(100)
    implicitHeight: 1

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.leftInset
        anchors.rightMargin: root.rightInset
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Theme.divider
    }

}
