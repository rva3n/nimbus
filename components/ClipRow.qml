import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: cr
    property var item: null
    property bool pinned: false
    implicitHeight: 46
    radius: 10
    color: crMouse.containsMouse ? Theme.surfaceHi : Theme.surface
    MouseArea {
        id: crMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: cr.pinned ? Clip.copyPin(cr.item) : Clip.copy(cr.item.id, cr.item.type)
    }
    RowLayout {
        anchors.fill: parent; anchors.margins: 8; spacing: 8
        Rectangle {
            visible: cr.item && cr.item.type === "image"
            Layout.preferredWidth: 44; Layout.preferredHeight: 30; radius: 6
            color: Theme.surfaceHi; clip: true
            Image {
                anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                source: (cr.item && cr.item.type === "image") ? ("file://" + cr.item.thumb) : ""
            }
        }
        Text {
            visible: !cr.item || cr.item.type !== "image"
            font.family: Theme.font; font.pixelSize: 14; color: Theme.accent; text: "\uf0f6"
        }
        Text {
            Layout.fillWidth: true
            font.family: Theme.font; font.pixelSize: 11; color: Theme.text
            elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
            text: cr.item ? (cr.item.type === "image" ? "Изображение"
                  : (cr.item.text !== undefined && cr.item.text !== "" ? cr.item.text : cr.item.preview)) : ""
        }
        RoundBtn { glyph: "\uf08d"; active: cr.pinned; onClicked: cr.pinned ? Clip.unpin(cr.item.id) : Clip.pin(cr.item.id) }
        RoundBtn { glyph: "\uf1f8"; danger: true; visible: !cr.pinned; onClicked: Clip.del(cr.item.id) }
    }
}
