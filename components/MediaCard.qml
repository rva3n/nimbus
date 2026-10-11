import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Карточка медиаплеера: анатомия медиа-карточки контроль-центра Lucid —
// заполненный withBlur(surfaceHigh) контейнер shapeLgInc, обложка dp(64)
// shapeLg, titleSmall/bodySmall, транспорт standard и тонкий seek ui/Slider.
// API прежний (artFile/artUrl/player, pos/seeking/dragFrac) — картой
// пользуются Lockscreen (и панель).
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

    implicitHeight: main.implicitHeight + Theme.dp(16)
    radius: Theme.shapeLgInc
    // глубина стекла следует за ползунком «Размытие фона» (Theme.glass)
    color: Theme.withBlur(Theme.mHigh)
    clip: true

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
        anchors.margins: Theme.dp(8)
        spacing: Theme.dp(6)

        RowLayout { // обложка + название/исполнитель + транспорт
            Layout.fillWidth: true
            spacing: Theme.dp(10)

            Rectangle { // обложка dp(64) shapeLg
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Theme.dp(64)
                Layout.preferredHeight: Theme.dp(64)
                radius: Theme.shapeLg
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

                LText {
                    Layout.fillWidth: true
                    role: "titleSmall"
                    color: Theme.text
                    text: mc.player ? (mc.player.trackTitle || "") : ""
                    elide: Text.ElideRight
                }

                LText {
                    Layout.fillWidth: true
                    role: "bodySmall"
                    color: Theme.subtext
                    text: mc.player ? (mc.player.trackArtist || "") : ""
                    elide: Text.ElideRight
                }
            }

            IconButton { // предыдущий трек
                Layout.alignment: Qt.AlignVCenter
                icon: "skip_previous"
                size: "s"
                disabled: !(mc.player && mc.player.canGoPrevious)
                onClicked: if (mc.player) mc.player.previous()
            }

            IconButton { // play / pause
                Layout.alignment: Qt.AlignVCenter
                icon: (mc.player && mc.player.isPlaying) ? "pause" : "play_arrow"
                variant: "filled"
                size: "s"
                onClicked: if (mc.player) mc.player.togglePlaying()
            }

            IconButton { // следующий трек
                Layout.alignment: Qt.AlignVCenter
                icon: "skip_next"
                size: "s"
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

            LText { // текущее время
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: timeMetrics.advanceWidth
                horizontalAlignment: Text.AlignRight
                role: "labelSmall"
                tabular: true
                color: Theme.subtext
                text: mc.fmtTime(mc.progress * mc.length)
            }

            Slider { // тонкий seek без бейджа; позиция опрашивается таймером
                id: bar
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                size: "xs"
                trackH: Theme.dp(6)
                handleH: Theme.dp(20)
                outerR: Theme.dp(3)
                from: 0
                to: Math.max(0, mc.length)
                value: mc.pos
                showValue: false
                inlineValue: false
                activeColor: Theme.accent
                inactiveColor: Theme.bgTrack
                // локальный preview; запись в плеер — только на отпускании
                onMoved: (v) => {
                    mc.seeking = true;
                    mc.dragFrac = mc.length > 0 ? v / mc.length : 0;
                }
                onCommitted: (v) => {
                    if (mc.player && mc.canSeek) {
                        mc.player.position = v;
                        mc.pos = v;
                    } else {
                        mc.pos = mc.num(mc.player ? mc.player.position : 0);
                    }
                    mc.seeking = false;
                }
            }

            LText { // полная длина
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: timeMetrics.advanceWidth
                horizontalAlignment: Text.AlignLeft
                role: "labelSmall"
                tabular: true
                color: Theme.subtext
                text: mc.fmtTime(mc.length)
            }
        }
    }

    // фикс. ширина подписей времени: дорожка не дёргается при смене цифр
    TextMetrics {
        id: timeMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeSize("labelSmall")
        font.weight: Theme.typeWeight("labelSmall")
        text: "00:00"
    }
}
