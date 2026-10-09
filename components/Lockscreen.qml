import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Lock screen UI. PAM lives in shell.qml and is passed in via `pam`.
WlSessionLock {
    id: lock
    property string username: "tony"
    property var pam: null
    property string errorText: ""
    property string typed: ""

    function submit() {
        if (lock.typed.length > 0 && lock.pam)
            lock.pam.respond(lock.typed);
    }

    onLockedChanged: if (lock.locked) { lock.typed = ""; }

    surface: Component {
        WlSessionLockSurface {
            id: lockSurface
            color: Theme.bgOpaque
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: lockSurface.now = new Date() }

            // фон: мягкий вертикальный градиент к чёрному снизу
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.a(Theme.bgOpaque, 0.0) }
                    GradientStop { position: 0.6; color: Theme.a(Theme.bgOpaque, 0.35) }
                    GradientStop { position: 1.0; color: Theme.scrim }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.dp(10)

                // часы: крупный display
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(lockSurface.now, "HH:mm")
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("displayLarge")
                    font.weight: Theme.typeWeight("displayLarge")
                }
                // дата
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: lockSurface.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
                    color: Theme.subtext
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("headlineSmall")
                    font.weight: Theme.typeWeight("headlineSmall")
                }

                Item { Layout.preferredHeight: Theme.dp(18) }

                // пользователь
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: lock.username
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodyLarge")
                    font.weight: Theme.typeWeight("bodyLarge")
                }

                // поле пароля
                TextField {
                    id: pwField
                    Layout.preferredWidth: Theme.dp(280)
                    Layout.alignment: Qt.AlignHCenter
                    placeholder: "Пароль"
                    echoMode: TextInput.Password
                    onTextChanged: lock.typed = pwField.text
                    onAccepted: lock.submit()
                    Component.onCompleted: forceActiveFocus()

                    // фокус и сброс поля при повторной блокировке
                    Connections {
                        target: lock
                        function onLockedChanged() {
                            if (lock.locked) {
                                pwField.text = "";
                                pwField.forceActiveFocus();
                            }
                        }
                    }
                }

                // ошибка аутентификации
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: lock.errorText !== ""
                    text: lock.errorText
                    color: Theme.error
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }

                // разблокировать
                Button {
                    Layout.preferredWidth: Theme.dp(280)
                    Layout.alignment: Qt.AlignHCenter
                    text: "Разблокировать"
                    variant: "filled"
                    size: "m"
                    onClicked: lock.submit()
                }
            }
        }
    }
}
