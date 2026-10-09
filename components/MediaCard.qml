import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Карточка медиаплеера: артворк + название/исполнитель + транспорт.
Rectangle {
    id: mc
    property string artFile: ""
    property string artUrl: ""
    property var player: null
    implicitHeight: Theme.dp(72)
    radius: Theme.radiusLg
    color: Theme.bgTile

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.dp(10)
        spacing: Theme.dp(10)

        Rectangle { // артворк 52x52
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Theme.dp(52)
            Layout.preferredHeight: Theme.dp(52)
            radius: Theme.radiusMd
            color: Theme.bgTrack
            clip: true

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: mc.artFile !== "" ? ("file://" + mc.artFile) : mc.artUrl
                visible: (mc.artFile !== "" || mc.artUrl !== "")
            }

            Icon { // заглушка без арта
                anchors.centerIn: parent
                visible: mc.artFile === "" && mc.artUrl === ""
                name: "music_note"
                size: Theme.dp(24)
                color: Theme.subtext
            }
        }

        ColumnLayout { // название и исполнитель
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("titleSmall")
                font.weight: Theme.typeWeight("titleSmall")
                color: Theme.text
                text: mc.player ? mc.player.trackTitle : ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
                color: Theme.subtext
                text: mc.player ? mc.player.trackArtist : ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        IconButton { // предыдущий трек
            Layout.alignment: Qt.AlignVCenter
            icon: "skip_previous"
            disabled: !(mc.player && mc.player.canGoPrevious)
            onClicked: mc.player.previous()
        }

        IconButton { // play / pause
            Layout.alignment: Qt.AlignVCenter
            icon: (mc.player && mc.player.isPlaying) ? "pause" : "play_arrow"
            variant: "filled"
            onClicked: if (mc.player) mc.player.togglePlaying()
        }

        IconButton { // следующий трек
            Layout.alignment: Qt.AlignVCenter
            icon: "skip_next"
            disabled: !(mc.player && mc.player.canGoNext)
            onClicked: mc.player.next()
        }
    }
}
