import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../core"
import "../../ui"

// Мини-плеер на рабочем столе: круглая обложка, название/исполнитель
// (Marquee), play/pause. Плеер выбирается как в MediaPill/MediaCard.
Rectangle {
    id: w

    color: Theme.withBlur(Theme.mHigh)
    radius: Theme.shapeLgInc
    clip: true
    implicitWidth: Theme.dp(296)
    implicitHeight: Math.max(cover.implicitHeight, txtCol.implicitHeight) + Theme.dp(28)

    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0)
            return null;
        for (const p of ps)
            if (p.isPlaying)
                return p;
        return ps[0];
    }
    readonly property bool playing: w.player !== null && w.player.isPlaying === true

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.dp(14)
        spacing: Theme.dp(12)

        Rectangle {
            id: cover

            implicitWidth: Theme.dp(56)
            implicitHeight: Theme.dp(56)
            radius: width / 2
            color: Theme.bgTrack
            clip: true

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: w.player ? w.player.trackArtUrl : ""
                visible: w.player !== null && w.player.trackArtUrl !== ""
            }

            Icon {
                anchors.centerIn: parent
                visible: !(w.player !== null && w.player.trackArtUrl !== "")
                name: "music_note"
                size: Theme.dp(24)
                color: Theme.subtext
            }

            // лёгкое вращение обложки, пока играет — как disc-режим MediaCard
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: w.playing
            }

        }

        ColumnLayout {
            id: txtCol

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Marquee {
                Layout.fillWidth: true
                role: "titleSmall"
                color: Theme.text
                text: w.player ? (w.player.trackTitle || "") : "Нет источника"
                scrolling: w.visible
            }

            Marquee {
                Layout.fillWidth: true
                visible: text !== ""
                role: "bodySmall"
                color: Theme.subtext
                text: w.player ? (w.player.trackArtist || "") : ""
                scrolling: w.visible
            }

        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            variant: "tonal"
            icon: w.playing ? "pause" : "play_arrow"
            onClicked: if (w.player !== null)
                w.player.togglePlaying()
        }

    }

}
