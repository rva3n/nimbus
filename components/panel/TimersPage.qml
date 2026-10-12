import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Таймеры»: переключатель «Таймер / Секундомер», крупный счётчик в
// кольце CircularProgress, пресеты и управление. Всё состояние — в синглтоне Chrono.
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

        Item { // кольцо с крупным счётчиком по центру
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.dp(196)

            CircularProgress {
                id: ring

                anchors.centerIn: parent
                width: Theme.dp(180)
                height: width
                thickness: Theme.dp(8)
                value: Chrono.totalSeconds > 0
                       ? Math.max(0, Math.min(1, Chrono.remaining / Chrono.totalSeconds))
                       : 0
                color: Chrono.timerDone ? Theme.error : Theme.accent
                trackColor: Theme.bgTrack
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.dp(2)

                LText {
                    Layout.alignment: Qt.AlignHCenter
                    role: "displayMedium"
                    tabular: true
                    color: Chrono.timerDone ? Theme.error : Theme.text
                    text: page.fmtTimer(Chrono.remaining)
                }

                LText {
                    Layout.alignment: Qt.AlignHCenter
                    role: "labelMedium"
                    color: Theme.subtext
                    text: Chrono.timerDone ? "Время вышло"
                        : Chrono.running ? "Идёт"
                        : Chrono.remaining > 0 ? "Пауза"
                        : "Готов"
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
            Layout.topMargin: Theme.dp(6)
            spacing: Theme.dp(8)

            Button {
                icon: Chrono.running ? "pause" : "play_arrow"
                text: Chrono.running ? "Пауза" : (Chrono.remaining > 0 ? "Продолжить" : "Старт")
                variant: "filled"
                onClicked: {
                    if (Chrono.running)
                        Chrono.pause();
                    else if (Chrono.remaining > 0)
                        Chrono.resume();
                    else
                        Chrono.start(Chrono.totalSeconds > 0 ? Chrono.totalSeconds : 5 * 60);
                }
            }

            Button {
                icon: "add"
                text: "+1 мин"
                variant: "tonal"
                onClicked: Chrono.addMin(1)
            }

            Button {
                icon: "restart_alt"
                text: "Сброс"
                variant: "tonal"
                disabled: Chrono.totalSeconds === 0 && Chrono.remaining === 0
                onClicked: Chrono.reset()
            }
        }
    }

    Card { // ── секундомер
        Layout.fillWidth: true
        visible: page.mode === "stopwatch"
        title: "Секундомер"

        LText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(8)
            horizontalAlignment: Text.AlignHCenter
            role: "displayMedium"
            tabular: true
            text: page.fmtSw(Chrono.swElapsed)
        }

        RowLayout { // управление
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.dp(8)
            spacing: Theme.dp(8)

            Button {
                icon: Chrono.swRunning ? "pause" : "play_arrow"
                text: Chrono.swRunning ? "Пауза" : "Старт"
                variant: "filled"
                onClicked: Chrono.swToggle()
            }

            Button {
                icon: "flag"
                text: "Круг"
                variant: "tonal"
                disabled: Chrono.swElapsed <= 0
                onClicked: Chrono.addLap()
            }

            Button {
                icon: "restart_alt"
                text: "Сброс"
                variant: "tonal"
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
                                 : Math.min(Chrono.laps.length, 5) * Theme.dp(48)
            clip: true
            spacing: Theme.dp(4)
            // новые круги — сверху
            model: Chrono.laps.slice().reverse()

            delegate: RowLayout { // компактная строка круга
                required property var modelData
                required property int index

                width: ListView.view.width
                height: Theme.dp(44)
                spacing: Theme.dp(12)

                LText {
                    Layout.alignment: Qt.AlignVCenter
                    role: "labelMedium"
                    tabular: true
                    color: Theme.subtext
                    text: "Круг " + (Chrono.laps.length - index)
                }

                Item { Layout.fillWidth: true }

                LText {
                    Layout.alignment: Qt.AlignVCenter
                    role: "titleSmall"
                    tabular: true
                    color: Theme.text
                    text: page.fmtSw(modelData)
                }
            }
        }

        LText {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.dp(4)
            visible: Chrono.laps.length === 0
            role: "bodySmall"
            color: Theme.subtextDim
            text: "Пока пусто — отметьте первый круг"
        }
    }
}
