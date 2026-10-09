import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Карточка медиаплеера v2: артворк 60×60, транспорт, тонкий seek-бар со временем.
// API прежний (artFile/artUrl/player) — картой пользуются RootPage и Lockscreen.
Rectangle {
    id: mc
    property string artFile: ""
    property string artUrl: ""
    property var player: null

    // локальная позиция (сек): Mpris position не реактивен при обычном воспроизведении
    property real pos: 0
    property bool seeking: false
    property real dragFrac: 0

    function num(v) { return (typeof v === "number" && isFinite(v)) ? v : 0 }
    function fracAt(px) { return Math.max(0, Math.min(1, px / Math.max(1, bar.width))) }
    function fmtTime(sec) { // m:ss
        const s = Math.max(0, Math.floor(mc.num(sec)));
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2);
    }

    readonly property real length: mc.num(mc.player ? mc.player.length : 0)
    // писать position можно только при canSeek + positionSupported
    readonly property bool canSeek: mc.player
        ? (mc.player.canSeek === true && mc.player.positionSupported !== false)
        : false
    readonly property real progress: mc.length > 0
        ? (mc.seeking ? mc.dragFrac : Math.max(0, Math.min(1, mc.pos / mc.length)))
        : 0

    implicitHeight: main.implicitHeight + Theme.dp(20)
    radius: Theme.radiusLg
    color: Theme.bgTile
    border.width: 1
    border.color: Theme.a(Theme.outline, 0.2)

    // позиция в Mpris меняется не реактивно — читаем её сами раз в 500 мс
    Timer {
        interval: 500
        repeat: true
        running: mc.player && mc.player.isPlaying === true
        onTriggered: if (!mc.seeking) mc.pos = mc.num(mc.player ? mc.player.position : 0)
    }

    Connections { // сик извне (нелинейный скачок) — превью обновляем сразу
        target: mc.player
        function onPositionChanged() { if (!mc.seeking) mc.pos = mc.num(mc.player ? mc.player.position : 0) }
        function onLengthChanged() { if (!mc.seeking) mc.pos = mc.num(mc.player ? mc.player.position : 0) }
    }

    // смена плеера — сброс позиции на актуальную
    onPlayerChanged: mc.pos = mc.num(mc.player ? mc.player.position : 0)

    ColumnLayout {
        id: main
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.dp(10)
        spacing: Theme.dp(6)

        RowLayout { // артворк + название/исполнитель + транспорт
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            Rectangle { // артворк 60×60
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Theme.dp(60)
                Layout.preferredHeight: Theme.dp(60)
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
                    size: Theme.dp(26)
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
                    text: mc.player ? (mc.player.trackTitle || "") : ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                    color: Theme.subtext
                    text: mc.player ? (mc.player.trackArtist || "") : ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            IconButton { // предыдущий трек
                Layout.alignment: Qt.AlignVCenter
                icon: "skip_previous"
                disabled: !(mc.player && mc.player.canGoPrevious)
                onClicked: if (mc.player) mc.player.previous()
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
                onClicked: if (mc.player) mc.player.next()
            }
        }

        RowLayout { // seek-бар: скрыт, пока у трека нет длины
            id: seekRow
            visible: mc.length > 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(2)
            spacing: Theme.dp(8)

            Text { // текущее время
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: timeMetrics.advanceWidth
                horizontalAlignment: Text.AlignRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
                color: Theme.subtext
                text: mc.fmtTime(mc.progress * mc.length)
            }

            Item { // дорожка: тонкая, своя — ui/Slider здесь не нужен
                id: bar
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Theme.dp(16)

                Rectangle { // фон дорожки
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.dp(5)
                    radius: height / 2
                    color: Theme.bgTrack

                    Rectangle { // заливка прогресса
                        id: fill
                        width: track.width * mc.progress
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent

                        // плавно между тиками таймера; при перетаскивании — без анимации
                        Behavior on width {
                            enabled: !mc.seeking
                            NumberAnimation {
                                duration: Theme.ms(460)
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }

                Rectangle { // ручка: видна на ховере/перетаскивании
                    id: thumb
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(12)
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    x: Math.max(-width / 2, Math.min(bar.width - width / 2, mc.progress * bar.width - width / 2))
                    opacity: (seekArea.containsMouse || mc.seeking) ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(120)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveEffects
                        }
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.topMargin: -Theme.dp(5)
                    anchors.bottomMargin: -Theme.dp(5)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // локальный preview; запись в плеер — только на отпускании
                    onPressed: (mouse) => { mc.seeking = true; mc.dragFrac = mc.fracAt(mouse.x); }
                    onPositionChanged: (mouse) => { if (pressed) mc.dragFrac = mc.fracAt(mouse.x); }
                    onReleased: {
                        if (!mc.seeking) return;
                        const target = mc.dragFrac * mc.length;
                        if (mc.player && mc.canSeek) { // запись в плеер — один раз, на отпускании
                            mc.player.position = target;
                            mc.pos = target;
                        } else {
                            mc.pos = mc.num(mc.player ? mc.player.position : 0);
                        }
                        mc.seeking = false;
                    }
                    onCanceled: {
                        mc.pos = mc.num(mc.player ? mc.player.position : 0);
                        mc.seeking = false;
                    }
                }
            }

            Text { // полная длина
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: timeMetrics.advanceWidth
                horizontalAlignment: Text.AlignLeft
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelSmall")
                font.weight: Theme.typeWeight("labelSmall")
                color: Theme.subtext
                text: mc.fmtTime(mc.length)
            }
        }
    }

    // фикс. ширина подписей времени: дорожка не дёргается при смене цифр
    TextMetrics {
        id: timeMetrics
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelSmall")
        font.weight: Theme.typeWeight("labelSmall")
        text: "00:00"
    }
}
