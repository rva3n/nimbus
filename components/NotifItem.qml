import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: ni
    property var item: null
    property int itemIndex: 0
    implicitHeight: 48
    radius: 12
    color: Theme.surface
    RowLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 10
        Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.accent; text: "\uf0f3" }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text { font.family: Theme.font; font.pixelSize: 12; color: Theme.text; text: (ni.item && ni.item.appName ? ni.item.appName + " · " : "") + (ni.item ? (ni.item.summary || "") : ""); elide: Text.ElideRight; Layout.fillWidth: true }
            Text { visible: text !== ""; font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext; text: ni.item ? (ni.item.body || "") : ""; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        IconBtn { glyph: "\uf00d"; onClicked: Notif.dismissAt(ni.itemIndex) }
    }
}
