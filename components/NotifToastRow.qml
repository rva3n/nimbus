import QtQuick
import QtQuick.Layouts
import "../core"

RowLayout {
    id: notifRow
    property var current: null
    spacing: 10
    Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.accent; text: "\uf0f3" }
    ColumnLayout {
        spacing: 0; Layout.maximumWidth: 300
        Text {
            font.family: Theme.font; font.pixelSize: 12; color: Theme.text
            text: notifRow.current ? ((notifRow.current.appName ? notifRow.current.appName + " · " : "") + (notifRow.current.summary || "")) : ""
            elide: Text.ElideRight; Layout.fillWidth: true
        }
        Text {
            visible: text !== ""
            font.family: Theme.font; font.pixelSize: 10; color: Theme.subtext
            text: notifRow.current ? (notifRow.current.body || "") : ""
            elide: Text.ElideRight; Layout.fillWidth: true
        }
    }
}
