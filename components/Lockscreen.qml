import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"

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
            color: Theme.bg
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: lockSurface.now = new Date() }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.a(Theme.surface, 0.0) }
                    GradientStop { position: 1.0; color: Theme.a("#000000", 0.55) }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(lockSurface.now, "HH:mm")
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 72; font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: lockSurface.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
                    color: Theme.subtext; font.family: Theme.font; font.pixelSize: 16
                }

                Item { Layout.preferredHeight: 16 }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: lock.username
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 15
                }

                Rectangle {
                    Layout.preferredWidth: 280; Layout.preferredHeight: 46; radius: 23
                    color: Theme.surface
                    border.width: 1
                    border.color: lock.errorText !== "" ? Theme.error : Theme.a(Theme.outline, 0.7)
                    TextInput {
                        id: pwField
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.font; font.pixelSize: 15
                        color: Theme.text
                        echoMode: TextInput.Password
                        focus: true
                        onTextChanged: lock.typed = text
                        onAccepted: lock.submit()
                        Component.onCompleted: forceActiveFocus()
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pwField.text === ""
                            text: "Пароль"
                            color: Theme.a(Theme.subtext, 0.5)
                            font: pwField.font
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: lock.errorText !== ""
                    text: lock.errorText
                    color: Theme.error; font.family: Theme.font; font.pixelSize: 12
                }

                Rectangle {
                    Layout.preferredWidth: 280; Layout.preferredHeight: 44; radius: 22
                    color: unlockMouse.containsMouse ? Theme.accent : Theme.a(Theme.accent, 0.9)
                    Text {
                        anchors.centerIn: parent
                        text: "Разблокировать"
                        color: Theme.bg; font.family: Theme.font; font.pixelSize: 14; font.bold: true
                    }
                    MouseArea {
                        id: unlockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: lock.submit()
                    }
                }
            }
        }
    }
}
