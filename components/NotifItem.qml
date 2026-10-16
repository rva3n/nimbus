import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Lucid-строка уведомления (анатомия lucidnotif/NotifCard + NotifActions):
// аватар 32dp, строка приложения + относительное время, summary и body на
// типографической шкале LText. Под телом — ряд не-default действий чипами
// (клик → action.invoke()) и, если raw.hasInlineReply, пилюля ответа:
// поле 32dp surfaceHighest + кнопка-круг 32 → shapeMd (sendInlineReply).
// Фон прозрачный, ховер — bgHover; закрытие — ghost-иконка (Notif.dismissAt);
// клик по строке — default-действие (invokeDefault), клики по чипам/полю
// не всплывают в него. API прежний: item / itemIndex, новый showApp (группы).
Item {
    id: ni

    property var item: null
    property int itemIndex: 0
    // группированный вид в панели: имя приложения рисует заголовок группы
    property bool showApp: true

    readonly property var _raw: ni.item ? ((ni.item.raw !== undefined && ni.item.raw !== null) ? ni.item.raw : ni.item) : null
    readonly property bool _canReply: !!(ni._raw && ni._raw.hasInlineReply)
    readonly property string _replyPlaceholder: ni._raw && ni._raw.inlineReplyPlaceholder ? ni._raw.inlineReplyPlaceholder : "Ответить…"
    // все действия, кроме default (он — клик по строке)
    readonly property var _actions: {
        const out = [];
        if (ni._raw && ni._raw.actions) {
            for (let i = 0; i < ni._raw.actions.length; i++) {
                const a = ni._raw.actions[i];
                if (a && a.identifier !== "default")
                    out.push(a);
            }
        }
        return out;
    }
    readonly property bool _hasExtra: ni._actions.length > 0 || ni._canReply

    property bool replyOpen: false

    readonly property string _app: ni.item ? (ni.showApp ? (ni.item.appName || "") : "") : ""
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

    function openReply() {
        if (!ni._canReply)
            return;

        ni.replyOpen = true;
        replyInput.forceActiveFocus();
    }

    function closeReply() {
        ni.replyOpen = false;
        replyInput.clear();
    }

    function sendReply() {
        const text = replyInput.text.trim();
        if (!ni._raw || text === "")
            return;

        try { ni._raw.sendInlineReply(text); } catch (e) {}
        ni.closeReply();
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

    implicitHeight: Math.max(Theme.dp(56), niLayout.implicitHeight + Theme.dp(16))

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.radiusMd
        color: niArea.containsMouse ? Theme.bgHover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
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
            color: (ni.item && ni.item.appIcon) ? "transparent" : Theme.accentContainer

            Icon {
                anchors.centerIn: parent
                visible: !(ni.item && ni.item.appIcon)
                name: "notifications"
                size: Theme.dp(18)
                color: Theme.fgAccentContainer
            }

            AppIcon {
                anchors.fill: parent
                visible: !!(ni.item && ni.item.appIcon)
                source: ni.item ? (ni.item.appIcon || "") : ""
                size: Theme.dp(32)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.dp(2)

            LText { // приложение · время
                Layout.fillWidth: true
                visible: text !== ""
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

            Flow { // действия (все, кроме default) — компактные чипы
                Layout.fillWidth: true
                Layout.topMargin: Theme.dp(6)
                spacing: Theme.dp(6)
                visible: ni._hasExtra && !ni.replyOpen

                Chip {
                    visible: ni._canReply
                    kind: "assist"
                    icon: "reply"
                    label: ni._replyPlaceholder !== "" && ni._replyPlaceholder.length < 24 ? ni._replyPlaceholder : "Ответить"
                    onClicked: ni.openReply()
                }

                Repeater {
                    model: ni._actions

                    Chip {
                        required property var modelData

                        kind: "assist"
                        label: modelData.text || ""
                        onClicked: {
                            try { modelData.invoke(); } catch (e) {}
                        }
                    }
                }
            }

            // пилюля ответа (Lucid NotifActions) — разворачивается по чипу
            // «Ответить»; высота анимируется emphasized-decel
            Item {
                id: replyWrap

                Layout.fillWidth: true
                implicitHeight: ni.replyOpen ? replyRow.implicitHeight : 0
                clip: true
                visible: ni.replyOpen || wrapAnim.running

                Behavior on implicitHeight {
                    NumberAnimation {
                        id: wrapAnim

                        duration: Theme.ms(220)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }
                }

                Row {
                    id: replyRow

                    anchors.top: parent.top
                    width: parent.width
                    spacing: Theme.dp(6)

                    Rectangle {
                        id: replyBox

                        width: parent.width - sendBtn.width - parent.spacing
                        height: Theme.dp(32)
                        radius: height / 2
                        color: Theme.surfaceHi
                        border.width: 1
                        border.color: replyInput.activeFocus ? Theme.primary : Theme.outline

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.durFastEffects
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: replyInput.forceActiveFocus()
                        }

                        LText {
                            x: Theme.dp(12)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: replyInput.text === ""
                            role: "bodySmall"
                            text: ni._replyPlaceholder
                            color: Theme.subtextDim
                        }

                        TextInput {
                            id: replyInput

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.dp(12)
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(12)
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.variableAxes: Theme.axes(Theme.typeSize("bodySmall"), 420, 0)
                            clip: true
                            selectByMouse: true
                            selectionColor: Theme.alpha(Theme.primary, 0.35)
                            selectedTextColor: Theme.text
                            // клик по полю не должен дойти до строки (default-действие)
                            onAccepted: ni.sendReply()
                            Keys.onEscapePressed: ni.closeReply()
                        }
                    }

                    // круг-кнопка отправки — единственное место, где уместен
                    // заполненный акцентный круг: 32 → shapeMd под нажатием
                    Rectangle {
                        id: sendBtn

                        width: Theme.dp(32)
                        height: Theme.dp(32)
                        radius: sendArea.pressed ? Theme.shapeMd : width / 2
                        color: replyInput.text.trim().length > 0 ? Theme.primary : Theme.surfaceHi

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durFastEffects
                            }
                        }

                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.ms(220)
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.easeEmphasizedDecel
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: "send"
                            size: Theme.dp(17)
                            color: replyInput.text.trim().length > 0 ? Theme.fgOnFill : Theme.subtextDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durFastEffects
                                }
                            }
                        }

                        MouseArea {
                            id: sendArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ni.sendReply()
                        }
                    }
                }
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
