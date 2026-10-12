import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../core"
import "../ui"

// Lock screen UI. PAM lives in shell.qml and is passed in via `pam`.
// Анатомия — Lucid lock: обои + frost (MultiEffect) + scrim-gradient, крупные
// двухстрочные часы, чипы-пилюли, центральная колонка dp(340), панель питания
// с двухшаговым подтверждением. Прибытие — по таймлайну Lucid (rv(delay)).
WlSessionLock {
    id: lock
    property string username: Quickshell.env("USER") || "user"
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

            // ── прибытие (таймлайн Lucid) ─────────────────────────────
            // линейный драйвер t: каждый блок сам смягчает свой отрезок
            property real t: 0
            readonly property real e: lockSurface.ease(lockSurface.t)
            // 0 — витрина, 1 — поле в фокусе: фон уходит назад, поле вперёд
            property real focusK: pwField.activeFocus ? 1 : 0
            readonly property int pad: Math.round(Math.max(Theme.dp(36), Math.min(Theme.dp(76), lockSurface.height * 0.062)))
            readonly property int clockUnit: Math.round(Math.max(Theme.dp(64), Math.min(Theme.dp(132), lockSurface.height * 0.14)))

            function clamp01(x) { return Math.max(0, Math.min(1, x)) }
            // длинный хвост: блок «приземляется», а не останавливается
            function ease(x) { const c = lockSurface.clamp01(x); return 1 - Math.pow(1 - c, 5) }
            // собственный прогресс блока: ничего до его очереди, затем полный ease
            function rv(delay) { return lockSurface.ease((lockSurface.t - delay) / Math.max(0.05, 1 - delay)) }

            Behavior on focusK {
                NumberAnimation {
                    duration: Theme.ms(520)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }
            }

            NumberAnimation {
                id: enterAnim
                target: lockSurface
                property: "t"
                to: 1
                duration: Theme.ms(900)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveStandard
            }

            Component.onCompleted: {
                lockSurface.t = 0;
                enterAnim.start();
            }

            // ── двухшаговое подтверждение питания ─────────────────────
            property string pending: ""
            readonly property var powerNames: ({ "logout": "Выйти", "reboot": "Перезагрузить", "poweroff": "Выключить" })

            function runPending() {
                const a = lockSurface.pending;
                lockSurface.pending = "";
                if (a === "logout") Sys.logout();
                else if (a === "reboot") Sys.reboot();
                else if (a === "poweroff") Sys.poweroff();
            }

            Connections {
                target: lock
                function onLockedChanged() {
                    if (lock.locked)
                        lockSurface.pending = "";
                }
            }

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
                    LText {
                        text: chip.label
                        role: "labelMedium"
                        color: chip.active ? Theme.text : Theme.subtextDim
                    }
                }
            }

            // ── фон: обои + frost + scrim gradient ─────────────────────
            Item {
                id: paperBox
                anchors.fill: parent
                visible: lock.wallpaperBg

                Image {
                    anchors.fill: parent
                    source: lock.wallpaperBg ? "file://" + Wallpaper.currentPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    // приезжает из push-in 1.07 и слушается фокуса (+0.02)
                    scale: 1.07 - 0.07 * lockSurface.e + lockSurface.focusK * 0.02
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: paperBox
                visible: lock.wallpaperBg
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: lockSurface.e * (0.35 + lockSurface.focusK * 0.45)
            }

            Rectangle {
                anchors.fill: parent
                visible: lock.wallpaperBg
                opacity: lockSurface.e * (0.42 + lockSurface.focusK * 0.16)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.cScrim, 0.75) }
                    GradientStop { position: 0.45; color: Theme.alpha(Theme.cScrim, 0.95) }
                    GradientStop { position: 1.0; color: Theme.cScrim }
                }
            }

            // цвет обоев, положенный назад поверх них (Material You)
            Rectangle {
                anchors.fill: parent
                visible: lock.wallpaperBg
                color: Theme.accent
                opacity: lockSurface.e * 0.07
            }

            // ── часы, дата, пользователь, чипы ────────────────────────
            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: lockSurface.pad + Theme.dp(14)
                anchors.topMargin: lockSurface.pad
                spacing: Theme.dp(6)
                opacity: lockSurface.rv(0.1)
                transform: Translate { y: (1 - lockSurface.rv(0.1)) * -Theme.dp(24) }

                // двухстрочные часы: час над минутой
                Column {
                    spacing: -Math.round(lockSurface.clockUnit * 0.24)

                    LText {
                        text: Qt.formatDateTime(lockSurface.now, "HH")
                        size: lockSurface.clockUnit
                        weight: 560
                        rounded: 100
                        tabular: true
                        color: Theme.text
                        font.letterSpacing: -Math.round(lockSurface.clockUnit * 0.03)
                    }
                    LText {
                        text: Qt.formatDateTime(lockSurface.now, "mm")
                        size: lockSurface.clockUnit
                        weight: 560
                        rounded: 100
                        tabular: true
                        color: Theme.primary
                        font.letterSpacing: -Math.round(lockSurface.clockUnit * 0.03)
                    }
                }

                LText {
                    text: lockSurface.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
                    role: "headlineSmall"
                    color: Theme.text
                }

                LText {
                    text: lock.username
                    role: "bodyLarge"
                    color: Theme.text
                }

                Row {
                    spacing: Theme.dp(8)
                    topPadding: Theme.dp(6)

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
                opacity: lockSurface.rv(0.24)
                transform: Translate { y: (1 - lockSurface.rv(0.24)) * Theme.dp(20) }

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

                    LText {
                        Layout.alignment: Qt.AlignHCenter
                        text: lock.username
                        role: "titleMedium"
                        color: Theme.text
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
                    LText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: lock.errorText !== ""
                        text: lock.errorText
                        role: "bodySmall"
                        color: Theme.error
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
            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.dp(44)
                spacing: Theme.dp(12)
                opacity: lockSurface.rv(0.5)
                transform: Translate { y: (1 - lockSurface.rv(0.5)) * Theme.dp(30) }

                // запрос подтверждения: только у разрушительных действий
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.dp(10)
                    visible: lockSurface.pending !== ""

                    LText {
                        Layout.alignment: Qt.AlignVCenter
                        role: "titleSmall"
                        color: Theme.text
                        text: (lockSurface.powerNames[lockSurface.pending] || "") + "?"
                    }
                    Button {
                        text: "Отмена"
                        variant: "text"
                        size: "s"
                        onClicked: lockSurface.pending = ""
                    }
                    Button {
                        text: lockSurface.powerNames[lockSurface.pending] || ""
                        variant: "filled"
                        size: "s"
                        danger: true
                        onClicked: lockSurface.runPending()
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
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
                        onClicked: lockSurface.pending = "logout"
                    }
                    IconButton {
                        icon: "restart_alt"
                        size: "m"
                        variant: "standard"
                        onClicked: lockSurface.pending = "reboot"
                    }
                    IconButton {
                        icon: "power_settings_new"
                        size: "m"
                        variant: "standard"
                        onClicked: lockSurface.pending = "poweroff"
                    }
                }
            }
        }
    }
}
