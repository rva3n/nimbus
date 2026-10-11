import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Lucid-строка уведомления (анатомия lucidnotif/NotifCard): аватар 32dp,
// строка приложения + относительное время, summary и body на типографической
// шкале LText. Фон прозрачный, ховер — bgHover; закрытие — ghost-иконка
// (Notif.dismissAt). API прежний: item / itemIndex.
Item {
    id: ni

    property var item: null
    property int itemIndex: 0

    readonly property string _app: ni.item ? (ni.item.appName || "") : ""
    readonly property string _time: ni.item ? ni.relTime(ni.item.ts) : ""
    readonly property string appLine: ni._app !== "" && ni._time !== "" ? ni._app + " · " + ni._time
        : (ni._app !== "" ? ni._app : ni._time)

    // относительное время из ts (ms). Пусто для старых записей без ts.
    function relTime(ts) {
        if (!ts)
            return "";

        const m = Math.floor((Date.now() - ts) / 60000);
        if (m < 1)
            return "сейчас";

        if (m < 60)
            return m + " мин";

        const h = Math.floor(m / 60);
        if (h < 24)
            return h + " ч";

        return Math.floor(h / 24) + " д";
    }

    implicitHeight: Math.max(Theme.dp(56), niLayout.implicitHeight + Theme.dp(16))

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.rad(16)
        color: niArea.containsMouse ? Theme.bgHover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
    }

    // клик по строке — действие по умолчанию (перейти к сообщению); запись
    // в истории остаётся. Кнопка закрытия лежит выше и получает клик сама.
    function invokeDefault() {
        const raw = ni.item && (ni.item.raw || ni.item);
        if (!raw || !raw.actions)
            return false;

        for (let i = 0; i < raw.actions.length; i++) {
            const a = raw.actions[i];
            if (a && a.identifier === "default") {
                try { a.invoke(); } catch (e) {}
                return true;
            }
        }
        return false;
    }

    MouseArea { // ховер фона + клик «перейти к сообщению»
        id: niArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ni.invokeDefault()
    }

    RowLayout {
        id: niLayout

        anchors.fill: parent
        anchors.margins: Theme.dp(8)
        spacing: Theme.dp(12)

        Rectangle { // аватар приложения 32×32
            Layout.alignment: Qt.AlignTop
            implicitWidth: Theme.dp(32)
            implicitHeight: Theme.dp(32)
            radius: Theme.radiusPill
            color: Theme.accentContainer

            Icon {
                anchors.centerIn: parent
                visible: !(ni.item && ni.item.appIcon)
                name: "notifications"
                size: Theme.dp(18)
                color: Theme.fgAccentContainer
            }

            AppIcon {
                anchors.centerIn: parent
                visible: !!(ni.item && ni.item.appIcon)
                source: ni.item ? (ni.item.appIcon || "") : ""
                size: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.dp(2)

            LText { // приложение · время
                Layout.fillWidth: true
                role: "labelSmall"
                color: Theme.subtextDim
                elide: Text.ElideRight
                text: ni.appLine
            }

            LText { // summary
                Layout.fillWidth: true
                visible: text !== ""
                role: "titleSmall"
                color: Theme.text
                elide: Text.ElideRight
                text: ni.item ? (ni.item.summary || "") : ""
            }

            LText { // тело
                Layout.fillWidth: true
                visible: text !== ""
                role: "bodySmall"
                color: Theme.subtext
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: ni.item ? (ni.item.body || "") : ""
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            icon: "close"
            size: "s"
            onClicked: Notif.dismissAt(ni.itemIndex)
        }
    }
}
