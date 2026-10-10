import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import QtQuick.Effects
import Quickshell.Wayland
import "../core"
import "../ui"

// Отдельный медиа-островок в левом верхнем углу экрана: есть плеер — виден,
// нет — скрыт. Показывает название и исполнителя, клик — play/pause.
PanelWindow {
    id: mp

    required property var modelData

    screen: modelData
    color: "transparent"
    anchors { top: true; left: true }
    implicitWidth: Theme.dp(420)
    implicitHeight: Theme.dp(84)
    margins { top: Theme.dp(4); left: Theme.dp(10) }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nimbus-media"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0)
            return null;
        for (const p of ps)
            if (p.isPlaying)
                return p;
        return ps[0];
    }
    readonly property bool fullscreenActive: mp.screen
        ? Umbriel.fullscreenFor(mp.screen.name, mp.screen.width, mp.screen.height) : false

    visible: mp.player !== null && !mp.fullscreenActive
    mask: Region { item: pill; radius: pill.radius }

    // тень как у острова: обёртка с запасом + layer.effect (MultiEffect)
    Item {
        id: shadowHost

        readonly property int padH: Theme.dp(26)
        readonly property int padTop: Theme.dp(8)
        readonly property int padBottom: Theme.dp(18)

        x: 0
        y: 0
        width: pill.width + padH * 2
        height: pill.height + padTop + padBottom
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.a(Theme.scrim, 0.68)
            shadowBlur: 0.9
            shadowVerticalOffset: Theme.dp(6)
            shadowOpacity: 1
        }

        Rectangle {
            id: pill

            x: shadowHost.padH
            y: shadowHost.padTop
            width: Theme.dp(300)
            height: Theme.dp(40)
            radius: height / 2
            color: Theme.bg
            border.width: 1
            border.color: Theme.a(Theme.outline, 0.25)
            clip: true

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(6)
                anchors.rightMargin: Theme.dp(14)
                spacing: Theme.dp(10)

                Rectangle { // play/pause
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(28)
                    height: width
                    radius: width / 2
                    color: Theme.alpha(Theme.accentContainer, 0.6)

                    Icon {
                        anchors.centerIn: parent
                        name: (mp.player && mp.player.isPlaying) ? "pause" : "play_arrow"
                        size: Theme.dp(15)
                        color: Theme.fgAccentContainer
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.dp(28) - Theme.dp(10)
                    spacing: 0

                    Text {
                        width: parent.width
                        color: Theme.text
                        text: mp.player ? (mp.player.trackTitle || "") : ""
                        elide: Text.ElideRight
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("titleSmall")
                        font.weight: Theme.typeWeight("titleSmall")
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        color: Theme.subtext
                        text: mp.player ? (mp.player.trackArtist || "") : ""
                        elide: Text.ElideRight
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("labelSmall")
                        font.weight: Theme.typeWeight("labelSmall")
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (mp.player) mp.player.togglePlaying()
            }
        }
    }
}
