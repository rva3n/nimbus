import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Календарь»: месяц сеткой 7×6, неделя с понедельника.
// Сегодняшний день — акцентный круг. Ориентир — MonthView из Lucid.
ColumnLayout {
    id: page

    property var win: null
    property int year: new Date().getFullYear()
    property int monthIndex: new Date().getMonth()
    // обновляется минутным таймером, чтобы подсветка «сегодня» не устаревала
    property date today: new Date()

    readonly property var weekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    readonly property var cells: {
        const now = page.today;
        const lead = (new Date(page.year, page.monthIndex, 1).getDay() + 6) % 7; // Пн = 0
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(page.year, page.monthIndex, 1 - lead + i);
            out.push({
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

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.dp(4)
                text: page.monthTitle
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("titleMedium")
                font.weight: Theme.typeWeight("titleMedium")
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

                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.subtext
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("labelSmall")
                    font.weight: Theme.typeWeight("labelSmall")
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
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.dp(38)

                    Rectangle { // круг «сегодня»
                        anchors.centerIn: parent
                        width: Theme.dp(32)
                        height: width
                        radius: width / 2
                        visible: modelData.today
                        color: Theme.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.today ? Theme.fgOnFill
                             : modelData.other ? Theme.subtextDim
                             : modelData.weekend ? Theme.subtext
                             : Theme.text
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("bodyMedium")
                        font.weight: modelData.today
                                     ? Theme.typeWeight("titleSmall")
                                     : Theme.typeWeight("bodyMedium")
                    }
                }
            }
        }
    }
}
