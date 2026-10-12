import QtQuick
import "../../core"
import "../../ui"

// Часы на рабочем столе: крупное tabular-время (Google Sans Flex) + дата.
Rectangle {
    id: w

    color: Theme.withBlur(Theme.mHigh)
    radius: Theme.shapeLgInc
    clip: true
    implicitWidth: Theme.dp(236)
    implicitHeight: col.implicitHeight + Theme.dp(36)

    property date now: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: w.visible
        triggeredOnStart: true
        onTriggered: w.now = new Date()
    }

    function two(n) { return (n < 10 ? "0" : "") + n; }

    // табличные цифры держат ширину «на месте» — бег не дёргает композицию
    readonly property string hourText: w.two(w.now.getHours()) + ":" + w.two(w.now.getMinutes())
    readonly property var wd: ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
    readonly property var mo: ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
    readonly property string dateText: w.wd[w.now.getDay()] + ", " + w.now.getDate() + " " + w.mo[w.now.getMonth()]

    Column {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.dp(18)
        spacing: Theme.dp(2)

        LText {
            width: parent.width
            size: Theme.dp(52)
            weight: 620
            rounded: 100
            tabular: true
            color: Theme.text
            text: w.hourText
        }

        LText {
            width: parent.width
            role: "bodyMedium"
            color: Theme.subtext
            elide: Text.ElideRight
            text: w.dateText
        }

    }

}
