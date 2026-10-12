import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Календарь»: месяц сеткой 7×6, неделя с понедельника. Сегодня —
// акцентный «пентагон» (MaterialShape), выбранный день — акцентный круг.
// Ориентир — MonthView из Lucid.
ColumnLayout {
    id: page

    property var win: null
    property int year: new Date().getFullYear()
    property int monthIndex: new Date().getMonth()
    // обновляется минутным таймером, чтобы подсветка «сегодня» не устаревала
    property date today: new Date()
    // { year, month, day } или null — выбранный день
    property var selected: null

    readonly property var weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    readonly property var cells: {
        const now = page.today;
        const lead = (new Date(page.year, page.monthIndex, 1).getDay() + 6) % 7; // Пн = 0
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(page.year, page.monthIndex, 1 - lead + i);
            out.push({
                "year": d.getFullYear(),
                "month": d.getMonth(),
                "day": d.getDate(),
                "other": d.getMonth() !== page.monthIndex,
                "weekend": d.getDay() === 0 || d.getDay() === 6,
                "today": d.getFullYear() === now.getFullYear()
                      && d.getMonth() === now.getMonth()
                      && d.getDate() === now.getDate()
            });
        }
        return out;
    }

    readonly property string monthTitle: {
        // Именительный падеж: «Октябрь 2026». toLocaleDateString("MMMM yyyy")
        // в ru-локали даёт родительный («октября 2026»).
        const loc = Qt.locale("ru_RU");
        const s = loc.standaloneMonthName(page.monthIndex, Locale.LongFormat) + " " + page.year;
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    visible: win !== null && win.mode === "panel" && win.page === "calendar"
    Layout.fillWidth: true
    spacing: Theme.dp(10)

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: page.today = new Date()
    }

    function prev() {
        let m = page.monthIndex - 1;
        let y = page.year;
        if (m < 0) {
            m = 11;
            y -= 1;
        }
        page.monthIndex = m;
        page.year = y;
    }
    function next() {
        let m = page.monthIndex + 1;
        let y = page.year;
        if (m > 11) {
            m = 0;
            y += 1;
        }
        page.monthIndex = m;
        page.year = y;
    }
    function goToday() {
        const n = page.today;
        page.year = n.getFullYear();
        page.monthIndex = n.getMonth();
        page.selected = { "year": n.getFullYear(), "month": n.getMonth(), "day": n.getDate() };
    }

    Card {
        Layout.fillWidth: true

        RowLayout { // навигация
            Layout.fillWidth: true
            spacing: Theme.dp(4)

            IconButton {
                icon: "chevron_left"
                onClicked: page.prev()
            }

            LText {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                role: "titleMedium"
                color: Theme.text
                elide: Text.ElideRight
                text: page.monthTitle
            }

            Chip {
                label: "Сегодня"
                onClicked: page.goToday()
            }

            IconButton {
                icon: "chevron_right"
                onClicked: page.next()
            }
        }

        RowLayout { // Пн…Вс
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(8)
            spacing: 0

            Repeater {
                model: page.weekdays

                LText {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    role: "labelSmall"
                    color: index >= 5 ? Theme.accent : Theme.subtext
                    text: modelData
                }
            }
        }

        GridLayout { // 7 × 6
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(2)
            columns: 7
            columnSpacing: 0
            rowSpacing: 0

            Repeater {
                model: page.cells

                Item {
                    id: cell

                    required property var modelData
                    readonly property bool isSelected: page.selected !== null
                        && page.selected.year === cell.modelData.year
                        && page.selected.month === cell.modelData.month
                        && page.selected.day === cell.modelData.day

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.dp(40)

                    // выбранный день — акцентный круг
                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.dp(34)
                        height: width
                        radius: width / 2
                        visible: cell.isSelected && !cell.modelData.today
                        color: Theme.accent

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durFastEffects
                            }
                        }
                    }

                    // сегодня — акцентный пентагон
                    Loader {
                        anchors.centerIn: parent
                        active: cell.modelData.today

                        sourceComponent: MaterialShape {
                            width: Theme.dp(40)
                            height: Theme.dp(40)
                            shape: "pentagon"
                            color: Theme.accent
                            scale: cellArea.pressed ? 0.9 : (cellArea.containsMouse ? 1.08 : 1)
                            rotation: cellArea.containsMouse ? -10 : 0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }
                            }

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.durDefaultSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }
                            }
                        }
                    }

                    LText {
                        anchors.centerIn: parent
                        role: "bodyMedium"
                        tabular: true
                        weight: cell.modelData.today || cell.isSelected ? 640 : 440
                        rounded: cell.modelData.today ? 100 : 0
                        color: cell.modelData.today || (cell.isSelected && !cell.modelData.today) ? Theme.fgOnFill
                             : cell.modelData.other ? Theme.subtextDim
                             : cell.modelData.weekend ? Theme.subtext
                             : Theme.text
                        text: cell.modelData.day
                    }

                    StateLayer {
                        id: cellArea

                        radius: Theme.dp(20)
                        tint: cell.modelData.today ? Theme.accent : Theme.text
                        hoverOpacity: cell.modelData.today ? 0 : Theme.stateHover
                        pressOpacity: cell.modelData.today ? 0 : Theme.statePressed
                        ripple: false
                        onClicked: page.selected = {
                            "year": cell.modelData.year,
                            "month": cell.modelData.month,
                            "day": cell.modelData.day
                        }
                    }
                }
            }
        }
    }
}
