pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../core"
import "../ui"
import "./widgets"

// Desktop-виджеты Oberon: карточки прямо на рабочем столе (по образцу Lucid).
// PanelWindow на WlrLayer.Bottom — под обычными окнами и под слоями Top/Overlay.
// ExclusiveZone не резервирует ничего (ExclusionMode.Ignore), на весь экран.
// Ввод: маска целиком пустая, пока НЕ идёт режим редактирования — клики проходят
// насквозь; в редактировании маска открывает всё окно, карточки тащатся мышью,
// правый клик (по пустому месту или по карточке) выключает редактор.
// Позиции/включённость — core/WidgetsStore.qml (~/.local/state/oberon/widgets.json).
PanelWindow {
    id: win

    required property var modelData

    screen: modelData
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // резерва нет; setting exclusiveZone here would steal from windows
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "oberon-widgets"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: Prefs.widgetsEnabled && WidgetsStore.ready

    // общий игрок слоя: visualizer прячется без воспроизведения, media — без плеера
    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0)
            return null;
        for (const p of ps)
            if (p.isPlaying)
                return p;
        return ps[0];
    }
    readonly property bool playerPlaying: win.player !== null && win.player.isPlaying === true

    Component {
        id: clkComp

        ClockWidget { }
    }

    Component {
        id: wthComp

        WeatherWidget { }
    }

    Component {
        id: sysComp

        SystemWidget { }
    }

    Component {
        id: medComp

        MediaWidget { }
    }

    Component {
        id: vizComp

        VisualizerWidget { }
    }

    Item {
        id: board

        anchors.fill: parent
        // нажатый drag-гость держит позицию локально, поэтому правки store
        // (в т.ч. перечитка файла) не дёргают карточку под курсором
        property bool editing: false

        readonly property var comps: ({
            "clock": clkComp,
            "weather": wthComp,
            "system": sysComp,
            "media": medComp,
            "visualizer": vizComp
        })

        EditingHint {
            id: hint

            editing: board.editing
            layerVisible: win.visible
            width: implicitWidth
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(34)
        }

        // фоновая зона: активна только в редактировании. ЛКМ — ничего (сброс),
        // ПКМ — выключить редактор. Пока board.editing === false, MouseArea
        // выключен и маска пуста — весь слой кликапрозрачный.
        MouseArea {
            id: emptyArea

            anchors.fill: parent
            z: -10
            enabled: board.editing
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    board.editing = false;
            }
        }

        Repeater {
            id: rep

            model: WidgetsStore.ready ? Object.keys(WidgetsStore.defs) : []

            delegate: Item {
                id: host

                required property string modelData

                readonly property var def: WidgetsStore.defs[host.modelData]
                readonly property bool on: WidgetsStore.isEnabled(host.modelData)
                // visualizer без звука и media без плеера не показываем вовсе
                readonly property bool claim: {
                    if (host.modelData === "visualizer")
                        return win.playerPlaying;
                    if (host.modelData === "media")
                        return win.player !== null;
                    return true;
                }
                readonly property bool shown: host.on && host.claim

                // px-анатомия карточки: ширина из store, высота — контент
                readonly property real dw: host.def ? Theme.dp(host.def.w) : Theme.dp(200)

                // позиция: во время перетаскивания — живые dragX/dragY, иначе store
                readonly property var storePos: WidgetsStore.posOf(host.modelData, board.defX(host.modelData), board.defY(host.modelData))
                property real dragX: 0
                property real dragY: 0
                property bool dragging: false

                readonly property real dh: loder.item ? (loder.item as Item).implicitHeight : (host.def ? Theme.dp(host.def.h) : Theme.dp(100))

                x: host.dragging ? host.dragX : host.storePos.x
                y: host.dragging ? host.dragY : host.storePos.y
                width: host.dw
                height: host.dh
                visible: host.shown
                opacity: host.shown ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(220)
                        easing.type: Easing.OutCubic
                    }

                }

                // «приподнимание» под курсором мыши в редакторе
                scale: host.dragging ? 1.04 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

                // тень: обёртка с запасом + MultiEffect (в Umbriel теней слоёв нет)
                Item {
                    id: shadowHost

                    readonly property int padH: Theme.dp(18)
                    readonly property int padTop: Theme.dp(10)
                    readonly property int padBottom: Theme.dp(18)

                    x: -shadowHost.padH
                    y: -shadowHost.padTop
                    width: shadowHost.padH * 2 + host.width
                    height: shadowHost.padTop + host.height + shadowHost.padBottom
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.a(Theme.scrim, 0.45)
                        shadowBlur: 0.55
                        shadowVerticalOffset: Theme.dp(4)
                        shadowOpacity: 0.75
                    }

                }

                Loader {
                    id: loder

                    width: host.width
                    height: item ? (item as Item).implicitHeight : Theme.dp(100)
                    sourceComponent: host.def ? board.comps[host.modelData] : null
                }

                // пунктирная обводка + ручка + «скрыть», только в редакторе
                EditFrame {
                    anchors.fill: parent
                    visible: board.editing
                    active: ma.containsMouse || host.dragging
                }

                Rectangle {
                    id: grip

                    visible: board.editing
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: Theme.dp(8)
                    width: Theme.dp(30)
                    height: Theme.dp(20)
                    radius: height / 2
                    color: Theme.a(Theme.accent, 0.92)

                    Icon {
                        anchors.centerIn: parent
                        name: "drag_indicator"
                        size: Theme.dp(14)
                        color: Theme.fgPrimary
                    }

                }

                IconButton {
                    visible: board.editing
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Theme.dp(8)
                    icon: "visibility_off"
                    tooltip: "Скрыть"
                    onClicked: WidgetsStore.toggle(host.modelData)
                }

                MouseArea {
                    id: ma

                    anchors.fill: parent
                    enabled: board.editing
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property real px0: 0
                    property real py0: 0

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            board.editing = false;
                            return ;
                        }
                        if (mouse.button !== Qt.LeftButton)
                            return ;
                        ma.px0 = mouse.x;
                        ma.py0 = mouse.y;
                        dl.freshGrab(host.x, host.y);
                        host.dragging = true;
                    }
                    onPositionChanged: (mouse) => {
                        if (!host.dragging || !(mouse.buttons & Qt.LeftButton))
                            return ;
                        dl.act(host.x + mouse.x - ma.px0, host.y + mouse.y - ma.py0);
                    }
                    onReleased: dl.drop()
                    onCanceled: dl.cancel()
                }

                // парковка логов drag в место, где они не мешают ридеру
                Item {
                    id: dl

                    function freshGrab(vx, vy) {
                        host.dragX = vx;
                        host.dragY = vy;
                    }

                    function act(nx, ny) {
                        const m = Theme.dp(8);
                        host.dragX = Math.max(m, Math.min(win.width - host.width - m, nx));
                        host.dragY = Math.max(m, Math.min(win.height - host.height - m, ny));
                    }

                    function drop() {
                        const g = Theme.dp(8);
                        // мягкий снап к сетке хранит «аккуратность» после ручного перетаскивания
                        dl.act(Math.round(host.dragX / g) * g, Math.round(host.dragY / g) * g);
                        WidgetsStore.move(host.modelData, host.dragX, host.dragY);
                        host.dragging = false;
                    }

                    function cancel() {
                        dl.drop();
                    }

                }

            }

        }

        // дефолт-позиции требуют экран этого окна
        function defX(id) {
            return WidgetsStore.defPos(id, board.width, board.height, Theme.uiScale).x;
        }

        function defY(id) {
            return WidgetsStore.defPos(id, board.width, board.height, Theme.uiScale).y;
        }

    }

    // ввод: пустая маска = клики проходят насквозь; в редакторе открывается всё
    mask: Region {
        x: 0
        y: 0
        width: board.editing ? win.width : 0
        height: board.editing ? win.height : 0
    }

    // пунктирная рамка редактора: активная — гуще и без мигания
    component EditFrame: Shape {
        id: edf

        // «гуще», когда рука на карточке
        property bool active: false
        readonly property real r: Theme.shapeLgInc
        readonly property color ink: Theme.a(Theme.accent, edf.active ? 0.95 : 0.45)

        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: "transparent"
            strokeColor: edf.ink
            strokeWidth: Math.max(1, Theme.dp(1.5))
            capStyle: ShapePath.RoundCap
            dashPattern: [Theme.dp(5), Theme.dp(6)]

            PathMove {
                x: edf.r
                y: 1
            }

            PathLine {
                x: edf.width - edf.r
                y: 1
            }

            PathArc {
                x: edf.width - 1
                y: edf.r
                radiusX: edf.r
                radiusY: edf.r
                direction: PathArc.Clockwise
            }

            PathLine {
                x: edf.width - 1
                y: edf.height - edf.r
            }

            PathArc {
                x: edf.width - edf.r
                y: edf.height - 1
                radiusX: edf.r
                radiusY: edf.r
                direction: PathArc.Clockwise
            }

            PathLine {
                x: edf.r
                y: edf.height - 1
            }

            PathArc {
                x: 1
                y: edf.height - edf.r
                radiusX: edf.r
                radiusY: edf.r
                direction: PathArc.Clockwise
            }

            PathLine {
                x: 1
                y: edf.r
            }

            PathArc {
                x: edf.r
                y: 1
                radiusX: edf.r
                radiusY: edf.r
                direction: PathArc.Clockwise
            }

        }

    }

    // подсказка: «ПКМ — редактировать» на включении виджетов, «ПКМ — готово»,
    // пока открыт редактор; затухает сама через 2.6с
    component EditingHint: Rectangle {
        id: eh

        property bool editing: false
        property bool layerVisible: false
        readonly property string text: eh.editing ? "ПКМ — готово" : "ПКМ — редактировать"
        // пробуждение: включение слоя и открытие редактора обе наводят руку
        onEditingChanged: if (eh.editing) eh.poke()
        onLayerVisibleChanged: if (eh.layerVisible) eh.poke()

        function poke() {
            flashTimer.restart();
        }

        implicitWidth: row.implicitWidth + Theme.dp(26)
        implicitHeight: Theme.dp(30)
        color: Theme.bg
        radius: height / 2
        visible: eh.opacity > 0.01
        opacity: flashTimer.running ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(520)
                easing.type: Easing.OutCubic
            }

        }

        Timer {
            id: flashTimer

            interval: 2600
            running: false
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Theme.dp(8)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: eh.editing ? "widgets" : "mouse"
                size: Theme.dp(16)
                color: Theme.fgPrimary
            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelMedium"
                color: Theme.subtext
                text: eh.text
            }

        }

    }
}
