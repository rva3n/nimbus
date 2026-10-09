import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
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

    // обои как фон — только статичные изображения
    readonly property bool wallpaperBg: Wallpaper.currentPath !== "" && !Wallpaper.currentIsVideo
    readonly property var battery: UPower.displayDevice
    // первый играющий плеер, иначе первый доступный
    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0) return null;
        for (const p of ps) if (p.isPlaying) return p;
        return ps[0];
    }
    readonly property string artUrl: {
        const p = lock.player;
        if (!p) return "";
        const u = p.trackArtUrl || "";
        return u.indexOf("/") === 0 ? "file://" + u : u;
    }

    surface: Component {
        WlSessionLockSurface {
            id: lockSurface
            color: Theme.bgOpaque
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: lockSurface.now = new Date() }

            // чип-пилюля состояния: иконка + подпись
            component StatusChip: Rectangle {
                id: chip
                property string icon: ""
                property string label: ""
                property bool active: true

                implicitWidth: chipRow.implicitWidth + Theme.dp(20)
                implicitHeight: Theme.dp(28)
                radius: Theme.pill(height)
                color: chip.active ? Theme.bgTile : Theme.a(Theme.bgTile, 0.5)
                border.width: 1
                border.color: Theme.a(Theme.outline, 0.3)

                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        name: chip.icon
                        size: Theme.dp(16)
                        color: chip.active ? Theme.text : Theme.subtextDim
                    }
                    Text {
                        text: chip.label
                        color: chip.active ? Theme.text : Theme.subtextDim
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("labelMedium")
                        font.weight: Theme.typeWeight("labelMedium")
                    }
                }
            }

            // ── фон: обои + затемнение + градиент ─────────────────────
            Image {
                anchors.fill: parent
                visible: lock.wallpaperBg
                source: lock.wallpaperBg ? "file://" + Wallpaper.currentPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
            Rectangle {
                anchors.fill: parent
                visible: lock.wallpaperBg
                color: Theme.scrim
                opacity: 0.45
            }
            Rectangle {
                anchors.fill: parent
                visible: lock.wallpaperBg
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.a(Theme.scrim, 0.0) }
                    GradientStop { position: 0.55; color: Theme.a(Theme.scrim, 0.15) }
                    GradientStop { position: 1.0; color: Theme.a(Theme.scrim, 0.5) }
                }
            }

            // ── часы, дата, пользователь, чипы ────────────────────────
            ColumnLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: Theme.dp(48)
                anchors.leftMargin: Theme.dp(56)
                spacing: Theme.dp(4)

                Text { // часы: крупный display
                    text: Qt.formatDateTime(lockSurface.now, "HH:mm")
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("displayLarge")
                    font.weight: Theme.typeWeight("displayLarge")
                }
                Text { // дата
                    text: lockSurface.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
                    color: Theme.subtext
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("headlineSmall")
                    font.weight: Theme.typeWeight("headlineSmall")
                }
                Text { // пользователь
                    Layout.topMargin: Theme.dp(8)
                    text: lock.username
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodyLarge")
                    font.weight: Theme.typeWeight("bodyLarge")
                }

                RowLayout { // статус: батарея, сеть, bluetooth, погода
                    Layout.topMargin: Theme.dp(12)
                    spacing: Theme.dp(8)

                    StatusChip {
                        visible: lock.battery !== null && lock.battery.isPresent
                        icon: "battery_full"
                        label: lock.battery ? Math.round((lock.battery.percentage || 0) * 100) + "%" : ""
                    }
                    StatusChip {
                        icon: "wifi"
                        label: "Wi-Fi"
                        active: Sys.wifiEnabled
                    }
                    StatusChip {
                        icon: "bluetooth"
                        label: "Bluetooth"
                        active: Sys.btEnabled
                    }
                    StatusChip {
                        visible: Weather.hasData
                        icon: Weather.icon
                        label: Math.round(Weather.temp) + "°"
                    }
                }
            }

            // ── медиа + карточка входа ────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                width: Theme.dp(340)
                spacing: Theme.dp(14)

                MediaCard {
                    visible: lock.player !== null
                    Layout.fillWidth: true
                    player: lock.player
                    artUrl: lock.artUrl
                    artFile: ""
                }

                Card {
                    Layout.fillWidth: true
                    pad: Theme.dp(18)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: lock.username
                        color: Theme.text
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("titleMedium")
                        font.weight: Theme.typeWeight("titleMedium")
                    }

                    // поле пароля
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.dp(8)
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
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: lock.errorText !== ""
                        text: lock.errorText
                        color: Theme.error
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall")
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // разблокировать
                    Button {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.dp(6)
                        text: "Разблокировать"
                        variant: "filled"
                        size: "m"
                        onClicked: lock.submit()
                    }
                }
            }

            // ── панель питания внизу ──────────────────────────────────
            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.dp(44)
                spacing: Theme.dp(14)

                IconButton {
                    icon: "bedtime"
                    size: "m"
                    variant: "standard"
                    onClicked: Sys.suspend()
                }
                IconButton {
                    icon: "logout"
                    size: "m"
                    variant: "standard"
                    onClicked: Sys.logout()
                }
                IconButton {
                    icon: "restart_alt"
                    size: "m"
                    variant: "standard"
                    onClicked: Sys.reboot()
                }
                IconButton {
                    icon: "power_settings_new"
                    size: "m"
                    variant: "standard"
                    onClicked: Sys.poweroff()
                }
            }
        }
    }
}
