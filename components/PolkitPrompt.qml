import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Модальное окно аутентификации polkit. Активный flow приходит из shell.qml
// (PolkitAgent.flow). Поверхность — Overlay во весь экран, чтобы гарантированно
// перекрыть остров; визуально повторяет карточку локскрина.
PanelWindow {
    id: root

    property var flow: null
    // показываем, пока запрос активен и ещё не завершён
    readonly property bool active: flow !== null && !flow.isCompleted

    visible: active
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nimbus-polkit"
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Отправка ответа (пароля) в flow.
    function submit() {
        if (!root.flow) return;
        root.flow.submit(pwField.text);
        pwField.text = "";
        pwField.forceActiveFocus();
    }
    // Отмена запроса со стороны пользователя.
    function cancel() {
        if (!root.flow) return;
        root.flow.cancelAuthenticationRequest();
        pwField.text = "";
    }

    // Новый запрос (или смена flow) — очищаем поле и забираем фокус.
    onFlowChanged: {
        pwField.text = "";
        if (root.active) pwField.forceActiveFocus();
    }
    onActiveChanged: {
        if (root.active) {
            pwField.text = "";
            pwField.forceActiveFocus();
        }
    }

    // Escape отменяет запрос независимо от того, какой ребёнок в фокусе.
    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: root.cancel()
    }

    // ── затемнение и перехват кликов ──────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea { anchors.fill: parent }
    }

    // ── карточка диалога ──────────────────────────────────────────────
    Card {
        id: dialog
        anchors.centerIn: parent
        width: Theme.dp(420)
        pad: Theme.dp(20)

        Text {
            Layout.fillWidth: true
            text: "Аутентификация"
            color: Theme.text
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("titleLarge")
            font.weight: Theme.typeWeight("titleLarge")
            elide: Text.ElideRight
        }

        // Основной текст запроса (например, «Authentication is required to …»).
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            visible: text !== ""
            text: root.flow ? root.flow.message : ""
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
            wrapMode: Text.WordWrap
        }

        // Подсказка поля ввода, если polkit её задал.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(2)
            visible: text !== ""
            text: root.flow ? root.flow.inputPrompt : ""
            color: Theme.subtextDim
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
            wrapMode: Text.WordWrap
        }

        // Пароль. responseVisible=false → маскируем (обычный случай).
        TextField {
            id: pwField
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(10)
            visible: root.flow === null || root.flow.isResponseRequired
            placeholder: "Пароль"
            echoMode: (root.flow && root.flow.responseVisible) ? TextInput.Normal : TextInput.Password
            onAccepted: root.submit()
            Keys.onEscapePressed: root.cancel()
        }

        // Ошибка попытки / доп. сообщение (остаток попыток polkit кладёт сюда).
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(4)
            readonly property string info: root.flow ? root.flow.supplementaryMessage : ""
            readonly property string fallback: (root.flow && root.flow.failed && info === "")
                ? "Неверный пароль. Попробуйте снова." : ""
            visible: info !== "" || fallback !== ""
            text: info !== "" ? info : fallback
            color: (root.flow && root.flow.supplementaryIsError) || fallback !== ""
                ? Theme.error : Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(10)
            spacing: Theme.dp(8)

            Item { Layout.fillWidth: true }

            Button {
                text: "Отмена"
                variant: "text"
                size: "m"
                onClicked: root.cancel()
            }
            Button {
                text: "Подтвердить"
                variant: "filled"
                size: "m"
                onClicked: root.submit()
            }
        }
    }
}
