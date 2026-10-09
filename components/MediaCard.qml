import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: mc
    property string artFile: ""
    property string artUrl: ""
    property var player: null
    implicitHeight: 68; radius: 16; color: Theme.surface
    RowLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 10
        Rectangle {
            Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 10; color: Theme.surfaceHi; clip: true
            Image {
                anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                source: mc.artFile !== "" ? ("file://" + mc.artFile) : mc.artUrl
                visible: (mc.artFile !== "" || mc.artUrl !== "")
            }
            Text {
                anchors.centerIn: parent
                visible: mc.artFile === "" && mc.artUrl === ""
                font.family: Theme.font; font.pixelSize: 20; color: Theme.subtext; text: "\uf001"
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text { font.family: Theme.font; font.pixelSize: 13; color: Theme.text; text: mc.player ? mc.player.trackTitle : ""; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: mc.player ? mc.player.trackArtist : ""; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        IconBtn { glyph: "\uf049"; btnEnabled: mc.player && mc.player.canGoPrevious; onClicked: mc.player.previous() }
        IconBtn { glyph: (mc.player && mc.player.isPlaying) ? "\uf04c" : "\uf04b"; onClicked: if (mc.player) mc.player.togglePlaying() }
        IconBtn { glyph: "\uf050"; btnEnabled: mc.player && mc.player.canGoNext; onClicked: mc.player.next() }
    }
}
