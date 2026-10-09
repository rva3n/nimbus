import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Таймеры»: переключатель «Таймер / Секундомер», крупное время,
// пресеты и управление. Всё состояние — в синглтоне Chrono.
ColumnLayout {
    id: page

    property var win: null
    property string mode: "timer"   // timer | stopwatch

    visible: win !== null && win.mode === "panel" && win.page === "timers"
    Layout.fillWidth: true
    spacing: Theme.dp(10)

    // mm:ss
    function fmtTimer(sec) {
        const t = Math.max(0, Math.round(sec));
        const m = Math.floor(t / 60);
        const s = t % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // mm:ss.d
    function fmtSw(v) {
        const tenths = Math.floor(Math.max(0, v) * 10 + 1e-6);
        const m = Math.floor(tenths / 600);
        const s = Math.floor(tenths / 10) % 60;
        const d = tenths % 10;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s + "." + d;
    }

    RowLayout { // режим
        Layout.fillWidth: true
        spacing: Theme.dp(8)

        Chip {
            label: "Таймер"
            selected: page.mode === "timer"
            onClicked: page.mode = "timer"
        }
        Chip {
            label: "Секундомер"
            selected: page.mode === "stopwatch"
            onClicked: page.mode = "stopwatch"
        }
        Item { Layout.fillWidth: true }
    }

    Card { // ── обратный отсчёт
        Layout.fillWidth: true
        visible: page.mode === "timer"
        title: "Таймер"

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            horizontalAlignment: Text.AlignHCenter
            text: page.fmtTimer(Chrono.remaining)
            color: Theme.text
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("displayMedium")
            font.weight: Theme.typeWeight("displayMedium")
        }

        Text {
            Layout.fillWidth: true
            visible: Chrono.timerDone
            horizontalAlignment: Text.AlignHCenter
            text: "Время вышло"
            color: Theme.accent
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelLarge")
            font.weight: Theme.typeWeight("labelLarge")
        }

        Item { // прогресс от общего времени
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            implicitHeight: Theme.dp(6)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.bgTrack
            }

            Rectangle {
                width: Chrono.totalSeconds > 0
                     ? parent.width * Math.max(0, Math.min(1, Chrono.remaining / Chrono.totalSeconds))
                     : 0
                height: parent.height
                radius: height / 2
                color: Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.ms(300)
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        RowLayout { // пресеты
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(6)
            spacing: Theme.dp(8)

            Repeater {
                model: [1, 5, 10, 25]

                Chip {
                    required property int modelData
                    label: modelData + " мин"
                    selected: Chrono.totalSeconds === modelData * 60
                    onClicked: Chrono.start(modelData * 60)
                }
            }
        }

        RowLayout { // управление
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(4)
            spacing: Theme.dp(12)

            IconButton {
                icon: "play_arrow"
                variant: "filled"
                size: "m"
                disabled: Chrono.running
                onClicked: Chrono.remaining > 0
                           ? Chrono.resume()
                           : Chrono.start(Chrono.totalSeconds > 0 ? Chrono.totalSeconds : 5 * 60)
            }
            IconButton {
                icon: "pause"
                variant: "filled"
                size: "m"
                disabled: !Chrono.running
                onClicked: Chrono.pause()
            }
            IconButton {
                icon: "restart_alt"
                variant: "tonal"
                size: "m"
                disabled: Chrono.totalSeconds === 0 && Chrono.remaining === 0
                onClicked: Chrono.reset()
            }
        }
    }

    Card { // ── секундомер
        Layout.fillWidth: true
        visible: page.mode === "stopwatch"
        title: "Секундомер"

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            horizontalAlignment: Text.AlignHCenter
            text: page.fmtSw(Chrono.swElapsed)
            color: Theme.text
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("displayMedium")
            font.weight: Theme.typeWeight("displayMedium")
        }

        RowLayout { // управление
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(6)
            spacing: Theme.dp(12)

            IconButton {
                icon: Chrono.swRunning ? "pause" : "play_arrow"
                variant: "filled"
                size: "m"
                onClicked: Chrono.swToggle()
            }
            IconButton {
                icon: "flag"
                variant: "tonal"
                size: "m"
                disabled: Chrono.swElapsed <= 0
                onClicked: Chrono.addLap()
            }
            IconButton {
                icon: "restart_alt"
                size: "m"
                disabled: Chrono.swElapsed <= 0
                onClicked: Chrono.swReset()
            }
        }
    }

    Card { // ── круги
        Layout.fillWidth: true
        visible: page.mode === "stopwatch"
        title: "Круги"
        actionIcon: Chrono.laps.length > 0 ? "delete" : ""
        onActionClicked: Chrono.laps = []

        ListView {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            Layout.preferredHeight: Chrono.laps.length === 0
                                 ? Theme.dp(36)
                                 : Math.min(Chrono.laps.length, 5) * Theme.dp(52)
            clip: true
            spacing: Theme.dp(6)
            // новые круги — сверху
            model: Chrono.laps.slice().reverse()

            delegate: RowLayout {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Theme.dp(46)
                spacing: Theme.dp(12)

                Rectangle { // номер круга 40×40
                    implicitWidth: Theme.dp(40)
                    implicitHeight: Theme.dp(40)
                    radius: Theme.radiusPill
                    color: Theme.bgTrack

                    Text {
                        anchors.centerIn: parent
                        text: Chrono.laps.length - index
                        color: Theme.subtext
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("labelMedium")
                        font.weight: Theme.typeWeight("labelMedium")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Круг " + (Chrono.laps.length - index)
                    color: Theme.text
                    elide: Text.ElideRight
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodyLarge")
                    font.weight: Theme.typeWeight("bodyLarge")
                }

                Text {
                    text: page.fmtSw(modelData)
                    color: Theme.subtext
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("titleSmall")
                    font.weight: Theme.typeWeight("titleSmall")
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.dp(4)
            visible: Chrono.laps.length === 0
            text: "Пока пусто — отметьте первый круг"
            color: Theme.subtextDim
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
        }
    }
}
