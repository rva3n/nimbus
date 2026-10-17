import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../core"
import "../ui"

// Компактный скриншот-тулбар (порт идеи lucidshot/SnapOverlay, но карточкой
// по центру сверху по образцу Switcher): Область / Экран / Текст (OCR) /
// Видео / Цвет. Область и Экран — grim+slurp в ~/Pictures/Screenshots с
// wl-copy и уведомлением (логика перенесена из shell.qml), OCR и цвет —
// scripts/shot-ocr.sh и scripts/shot-color.sh, видео — toggle wf-recorder
// через scripts/shot-video.sh (pid-файл в /tmp). Держим окно скрытым перед
// захватами: скрипты стартуют с паузы, чтобы слой успел исчезнуть.
PanelWindow {
    id: toolbar

    signal closed()

    property bool shown: false

    property real reveal: toolbar.shown ? 1 : 0
    property int _focus: 0
    property string mode: "region"

    readonly property var modes: [{
        "id": "region",
        "label": "Область",
        "icon": "screenshot_region"
    }, {
        "id": "full",
        "label": "Экран",
        "icon": "fullscreen"
    }, {
        "id": "ocr",
        "label": "Текст",
        "icon": "text_fields"
    }, {
        "id": "video",
        "label": "Видео",
        "icon": "videocam"
    }, {
        "id": "color",
        "label": "Цвет",
        "icon": "colorize"
    }]

    // зависим только от системного каталога: файлы лежат рядом с корнем шелла
    readonly property string scriptsDir: Qt.resolvedUrl("../scripts/").toString().replace("file://", "")
    readonly property string recPidFile: "/tmp/oberon-recorder.pid"
    property bool recording: false

    function open(mode) {
        toolbar.mode = mode || "region";
        const i = toolbar.modes.findIndex((m) => m.id === toolbar.mode);
        toolbar._focus = i >= 0 ? i : 0;
        toolbar.shown = true;
        recProc.running = false;
        recProc.running = true;
    }

    function close() {
        toolbar.shown = false;
        toolbar.recording = false;
    }

    function activate(index) {
        const m = toolbar.modes[index];
        if (!m) return;
        if (m.id === "video") {
            // toggle: окно остаётся (даже можно закрыть — запись продолжится)
            runScript("shot-video.sh");
            statePoll.restart();
            return;
        }
        toolbar.close();
        // слой должен исчезнуть до slurp/grim: пауза в командах
        Qt.callLater(() => {
            if (m.id === "region") shoot(false);
            else if (m.id === "full") shoot(true);
            else if (m.id === "ocr") runScript("shot-ocr.sh");
            else if (m.id === "color") runScript("shot-color.sh");
        });
    }

    function runScript(name) {
        Quickshell.execDetached(["sh", toolbar.scriptsDir + name]);
    }

    // прежнее поведение screenshotRegion/screenshotFull из shell.qml, только с
    // паузой, чтобы тулбар успел скрыться перед slurp
    function shoot(fullscreen) {
        Quickshell.execDetached(["sh", "-c",
            "sleep 0.25; mkdir -p \"$HOME/Pictures/Screenshots\"; f=\"$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png\"; " +
            "if grim" + (fullscreen ? "" : " -g \"$(slurp)\"") + " \"$f\" 2>/dev/null; then wl-copy < \"$f\"; " +
            "notify-send -a Oberon 'Скриншот' '" + (fullscreen ? "Весь экран сохранён и скопирован" : "Область сохранена и скопирована") + "'; fi"]);
    }

    onShownChanged: {
        if (toolbar.shown) catcher.forceActiveFocus();
        else closed();
    }

    visible: toolbar.shown || toolbar.reveal > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oberon-shottoolbar"
    WlrLayershell.keyboardFocus: toolbar.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Behavior on reveal {
        NumberAnimation {
            duration: toolbar.shown ? Theme.durFastSpatial : Theme.durFastEffects
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }
    }

    // клик мимо карточки — закрыть
    MouseArea {
        anchors.fill: parent
        onClicked: toolbar.close()
    }

    // ── карточка по центру сверху ─────────────────────────────────────
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.topReserve + Theme.dp(24)
        width: row.implicitWidth + Theme.dp(28)
        height: Theme.dp(96)
        radius: Theme.shapeXl
        color: Theme.bg
        opacity: toolbar.reveal
        transform: Translate { y: (1 - toolbar.reveal) * -Theme.dp(12) }

        MouseArea { anchors.fill: parent }   // клики внутри не закрывают

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.dp(8)

            Repeater {
                model: toolbar.modes

                Item {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool focused: toolbar._focus === tile.index
                    readonly property bool hot: tile.focused || tap.containsMouse
                    readonly property bool isVideo: tile.modelData.id === "video"

                    width: Theme.dp(76)
                    height: card.height - Theme.dp(16)

                    Rectangle {
                        id: face

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: Theme.dp(58)
                        height: Theme.dp(58)
                        radius: height / 2
                        color: toolbar.recording && tile.isVideo ? Theme.error
                            : (tile.hot ? Theme.primaryContainer : Theme.bgTile)
                        scale: tap.pressed ? 0.94 : (tile.hot ? 1.04 : 1)

                        Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }
                        }

                        // StateLayer кладётся поверх, рябь обрезается по кругу
                        StateLayer {
                            id: tap
                            anchors.fill: parent
                            radius: parent.radius
                            tint: toolbar.recording && tile.isVideo ? Theme.fgError : Theme.text
                            onClicked: toolbar.activate(tile.index)
                            onEntered: {
                                if (toolbar._focus !== tile.index) toolbar._focus = tile.index;
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: toolbar.recording && tile.isVideo ? "stop" : tile.modelData.icon
                            size: Theme.dp(26)
                            color: toolbar.recording && tile.isVideo ? Theme.fgError
                                : (tile.hot ? Theme.fgPrimaryContainer : Theme.text)
                        }
                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.dp(4)
                        role: "labelSmall"
                        color: tile.hot ? Theme.primary : Theme.subtext
                        text: toolbar.recording && tile.isVideo ? "Стоп" : tile.modelData.label

                        Behavior on color { ColorAnimation { duration: Theme.durFastEffects } }
                    }
                }
            }
        }

        // индикатор активной записи — над карточкой
        Row {
            visible: toolbar.recording
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: Theme.dp(12)
            spacing: Theme.dp(6)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(8)
                height: Theme.dp(8)
                radius: height / 2
                color: Theme.error
            }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelSmall"
                color: Theme.subtext
                text: "ведётся запись"
            }
        }
    }

    // ── клавиатура ────────────────────────────────────────────────────
    Item {
        id: catcher
        anchors.fill: parent
        focus: toolbar.shown

        Keys.onPressed: (event) => {
            if (!toolbar.shown) { event.accepted = true; return; }
            if (event.key === Qt.Key_Escape) {
                toolbar.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                toolbar._focus = (toolbar._focus + toolbar.modes.length - 1) % toolbar.modes.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                toolbar._focus = (toolbar._focus + 1) % toolbar.modes.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                toolbar.activate(toolbar._focus);
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                toolbar.activate(event.key - Qt.Key_1);
                event.accepted = true;
            }
        }
    }

    // статус записи — по pid-файлу из shot-video.sh
    Timer {
        id: statePoll
        interval: 800
        repeat: true
        running: toolbar.shown
        onTriggered: {
            recProc.running = false;
            recProc.running = true;
        }
    }

    Process {
        id: recProc
        command: ["sh", "-c", "[ -f " + toolbar.recPidFile + " ] && kill -0 \"$(cat " + toolbar.recPidFile + ")\" 2>/dev/null && echo recording || echo idle"]
        stdout: StdioCollector {
            onStreamFinished: toolbar.recording = text.indexOf("recording") !== -1
        }
    }
}
