import QtQuick
import "../core"

// Один месяц: выбор дня или взгляд на него (порт lucidui/MonthView.qml).
// Сегодня держит люсидовский пятиугольник, выбранный день сидит в тональном
// круге, напоминание оставляет точку. Перелистывание въезжает слайдом.
Item {
    id: month

    property int year: month.now.getFullYear()
    property int monthIndex: month.now.getMonth()
    // { year, month, day } или null
    property var selected: null
    property int cell: Theme.dp(40)
    property real slideX: 0
    property bool mondayFirst: true
    property bool showHeader: true
    property bool showNav: true
    // часы: компонент тикает сам (live). Внешний владелец, привязавший now,
    // должен выставить live = false, чтобы таймер не рвал привязку.
    property date now: new Date()
    property bool live: true
    // метки напоминаний: функция (y, m, d) → bool либо карта "y-m-d" → bool
    property var marked: null
    // подписи дней недели; null — одиночные буквы по mondayFirst
    property var weekdayLabels: null
    // чернила, для месяца, нарисованного на тональной карточке
    property color ink: Theme.text
    property color inkDim: Theme.subtext
    property color accent: Theme.primary
    property color fgAccent: Theme.fgPrimary
    property color pickFill: Theme.secondaryContainer
    property color pickInk: Theme.fgSecondaryContainer
    property color markColor: Theme.tertiary
    // этот месяц как year * 12 + month; ведёт его суточный тик
    property int thisMonth: month.now.getFullYear() * 12 + month.now.getMonth()
    readonly property bool isCurrent: month.year * 12 + month.monthIndex === month.thisMonth
    readonly property var weekdays: month.weekdayLabels !== null ? month.weekdayLabels : (month.mondayFirst ? ["M", "T", "W", "T", "F", "S", "S"] : ["S", "M", "T", "W", "T", "F", "S"])
    readonly property var cells: {
        const now = month.now;
        const lead = (new Date(month.year, month.monthIndex, 1).getDay() + (month.mondayFirst ? 6 : 0)) % 7;
        const first = new Date(month.year, month.monthIndex, 1 - lead);
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i);
            out.push({
                "year": d.getFullYear(),
                "month": d.getMonth(),
                "day": d.getDate(),
                "other": d.getMonth() !== month.monthIndex,
                "today": d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate(),
                "marked": month.isMarked(d.getFullYear(), d.getMonth(), d.getDate())
            });
        }
        return out;
    }

    signal picked(int y, int m, int d)

    function isMarked(y, m, d) {
        if (month.marked === null || month.marked === undefined)
            return false;
        if (typeof month.marked === "function")
            return !!month.marked(y, m, d);
        return !!month.marked[y + "-" + m + "-" + d];
    }

    function page(dir) {
        let m = month.monthIndex + dir;
        let y = month.year;
        if (m < 0) {
            m = 11;
            y -= 1;
        } else if (m > 11) {
            m = 0;
            y += 1;
        }
        month.year = y;
        month.monthIndex = m;
        slideIn.from = dir * 42;
        slideIn.restart();
    }

    function goToday() {
        const n = month.now;
        const dir = (n.getFullYear() * 12 + n.getMonth()) >= (month.year * 12 + month.monthIndex) ? 1 : -1;
        month.year = n.getFullYear();
        month.monthIndex = n.getMonth();
        slideIn.from = dir * 42;
        slideIn.restart();
    }

    // часовая отметка: компонент сам следует за полуночью в новый месяц
    function _tick() {
        const n = new Date();
        const cur = n.getFullYear() * 12 + n.getMonth();
        if (cur === month.thisMonth) {
            month.now = n;
            return ;
        }
        if (month.isCurrent) {
            month.year = n.getFullYear();
            month.monthIndex = n.getMonth();
        }
        month.thisMonth = cur;
        month.now = n;
    }

    implicitWidth: month.cell * 7
    implicitHeight: (month.showHeader ? head.height + Theme.dp(6) : 0) + weekRow.height + month.cell * 6

    Timer {
        interval: 60000
        repeat: true
        running: month.live
        onTriggered: month._tick()
    }

    NumberAnimation {
        id: slideIn

        target: month
        property: "slideX"
        to: 0
        duration: Theme.durDefaultSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveDefaultSpatial
    }

    Item {
        id: head

        visible: month.showHeader
        width: parent.width
        height: month.showHeader ? Theme.dp(36) : 0

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.dp(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(6)

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleMedium"
                weight: 600
                color: month.accent
                text: new Date(month.year, month.monthIndex, 1).toLocaleDateString(Qt.locale(), "MMMM")
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "titleMedium"
                weight: 420
                color: month.inkDim
                text: month.year
            }

        }

        Row {
            visible: month.showNav
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            IconButton {
                visible: !month.isCurrent
                icon: "today"
                size: "xs"
                tintOverride: month.inkDim
                onClicked: month.goToday()
            }

            IconButton {
                icon: "chevron_left"
                size: "xs"
                tintOverride: month.inkDim
                onClicked: month.page(-1)
            }

            IconButton {
                icon: "chevron_right"
                size: "xs"
                tintOverride: month.inkDim
                onClicked: month.page(1)
            }

        }

    }

    Item {
        id: body

        anchors.top: head.bottom
        anchors.topMargin: month.showHeader ? Theme.dp(6) : 0
        width: parent.width
        height: weekRow.height + month.cell * 6
        clip: true

        Item {
            x: month.slideX
            width: parent.width
            height: parent.height
            opacity: 1 - Math.abs(month.slideX) / 60

            Row {
                id: weekRow

                width: parent.width
                height: Theme.dp(22)

                Repeater {
                    model: month.weekdays

                    LText {
                        required property var modelData
                        required property int index

                        width: month.cell
                        horizontalAlignment: Text.AlignHCenter
                        role: "labelMedium"
                        color: (month.mondayFirst ? index >= 5 : (index === 0 || index === 6)) ? month.accent : month.inkDim
                        text: modelData
                    }

                }

            }

            Grid {
                anchors.top: weekRow.bottom
                columns: 7

                Repeater {
                    model: month.cells

                    Item {
                        id: c

                        required property var modelData
                        readonly property bool isSelected: month.selected !== null && month.selected.year === c.modelData.year && month.selected.month === c.modelData.month && month.selected.day === c.modelData.day

                        width: month.cell
                        height: month.cell

                        Rectangle {
                            anchors.centerIn: parent
                            width: month.cell - Theme.dp(4)
                            height: month.cell - Theme.dp(4)
                            radius: width / 2
                            color: c.isSelected && !c.modelData.today ? month.pickFill : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durFastEffects
                                }

                            }

                        }

                        // одна ячейка из 42 показывает его, и каждая стоит кривой из JS
                        Loader {
                            anchors.centerIn: parent
                            active: c.modelData.today

                            sourceComponent: MaterialShape {
                                width: month.cell
                                height: month.cell
                                shape: "pentagon"
                                color: month.accent
                                scale: todayArea.pressed ? 0.92 : (todayArea.containsMouse ? 1.1 : 1)
                                rotation: todayArea.containsMouse ? -12 : 0

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

                        StateLayer {
                            id: area

                            anchors.fill: undefined
                            anchors.centerIn: parent
                            width: month.cell - Theme.dp(4)
                            height: month.cell - Theme.dp(4)
                            radius: width / 2
                            visible: !c.modelData.today
                            onClicked: month.picked(c.modelData.year, c.modelData.month, c.modelData.day)
                        }

                        StateLayer {
                            id: todayArea

                            anchors.fill: undefined
                            anchors.centerIn: parent
                            width: month.cell - Theme.dp(4)
                            height: month.cell - Theme.dp(4)
                            radius: width / 2
                            visible: c.modelData.today
                            // сегодня отвечает наклоном и раздутием самой фигуры, слой
                            // здесь только ради клика и курсора
                            hoverOpacity: 0
                            pressOpacity: 0
                            ripple: false
                            onClicked: month.picked(c.modelData.year, c.modelData.month, c.modelData.day)
                        }

                        TextMetrics {
                            id: dayCap

                            font: dayText.font
                            text: "7"
                        }

                        FontMetrics {
                            id: dayFm

                            font: dayText.font
                        }

                        LText {
                            id: dayText

                            anchors.horizontalCenter: parent.horizontalCenter
                            // центрируем бокс высоты прописной, а не строки
                            y: (c.height - dayCap.tightBoundingRect.height) / 2 - dayCap.tightBoundingRect.y - dayFm.ascent
                            role: "bodyMedium"
                            weight: c.modelData.today || c.isSelected ? 650 : 440
                            rounded: c.modelData.today ? 100 : 0
                            color: c.modelData.today ? month.fgAccent : (c.isSelected ? month.pickInk : month.ink)
                            opacity: c.modelData.other && !c.modelData.today ? 0.35 : 1
                            text: c.modelData.day
                        }

                        Rectangle {
                            visible: c.modelData.marked
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.dp(5)
                            width: Theme.dp(5)
                            height: Theme.dp(5)
                            radius: 2.5
                            color: c.modelData.today ? month.fgAccent : month.markColor
                        }

                    }

                }

            }

        }

    }

}
