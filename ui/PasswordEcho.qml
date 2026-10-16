import QtQuick
import QtQuick.Shapes
import "../core"
import "Shapes.js" as Shapes

// Набранный секрет: каждый символ ложится случайной m3-фигурой, поворачивается,
// затем плавится в точку (порт lucidui/PasswordEcho.qml). reveal превращает
// каждую точку в её букву прямо на месте.
Item {
    id: echo

    property string text: ""
    property bool reveal: false
    // рябь, пока ответ на виду
    property bool busy: false
    property int selectionStart: 0
    property int selectionEnd: 0
    property color color: Theme.text
    property color band: Theme.accentContainer
    property color picked: Theme.fgAccentContainer
    // заливка самого поля, чтобы переполненный ряд таял под его краем
    property color edge: "transparent"
    property font font
    property real dot: Theme.dp(12)
    property real gap: Theme.dp(4)
    readonly property var deck: ["slanted", "arch", "fan", "arrow", "semiCircle", "triangle", "diamond", "clamShell", "pentagon", "gem", "sunny", "verySunny", "cookie4", "ghostish", "softBurst"]
    property color tint: echo.color
    property real wave: 0
    property real swell: echo.busy ? 1 : 0
    property var bag: []
    property string last: ""
    property string was: ""
    property int serial: 0

    function draw() {
        if (echo.bag.length === 0) {
            var b = echo.deck.slice();
            for (var i = b.length - 1; i > 0; i--) {
                var j = Math.floor(Math.random() * (i + 1));
                var t = b[i];
                b[i] = b[j];
                b[j] = t;
            }
            // свежая тасовка не должна повторить только что выданную фигуру
            if (b[b.length - 1] === echo.last) {
                b[b.length - 1] = b[0];
                b[0] = echo.last;
            }
            echo.bag = b;
        }
        echo.last = echo.bag.pop();
        return echo.last;
    }

    // одна непрерывная правка на изменение: что ушло — закапывается, что пришло — сдаётся
    function sync() {
        var a = echo.was, b = echo.text;
        if (a === b)
            return ;

        var live = [];
        for (var r = 0; r < beads.count; r++) {
            if (!beads.get(r).dying)
                live.push(r);

        }
        if (live.length !== a.length)
            a = "";

        var lim = Math.min(a.length, b.length);
        var p = 0;
        while (p < lim && a.charCodeAt(p) === b.charCodeAt(p))
            p++;
        var s = 0;
        while (s < lim - p && a.charCodeAt(a.length - 1 - s) === b.charCodeAt(b.length - 1 - s))
            s++;
        var cut = a === "" ? live.length : a.length - p - s;
        var from = a === "" ? 0 : p;
        // очищенное поле тает на месте, а не складывается внутрь
        for (var k = 0; k < cut; k++) {
            beads.setProperty(live[from + k], "ghost", echo.reveal && a !== "" ? a.charAt(from + k) : "");
            beads.setProperty(live[from + k], "hold", b === "");
            beads.setProperty(live[from + k], "dying", true);
        }
        // то, что заменяет ряд, ложится впереди него, где старый текст начинался
        var at = from < live.length ? live[from] : beads.count;
        var add = b.length - p - s;
        // вставка ложится быстрым рядом, а не вся разом
        for (var n = 0; n < add; n++) {
            beads.insert(at + n, {
                "uid": ++echo.serial,
                "shape": echo.draw(),
                "tilt": Math.random() * 90 - 45,
                "turn": (Math.random() < 0.5 ? -1 : 1) * (150 + Math.random() * 110),
                "lag": Theme.ms(Math.min(n, 12) * 24),
                "at": 0,
                "ghost": "",
                "hold": false,
                "dying": false
            });
        }
        var i = 0;
        for (var q = 0; q < beads.count; q++)
            beads.setProperty(q, "at", beads.get(q).dying ? -1 : i++);
        echo.was = b;
    }

    function bury(uid) {
        for (var r = 0; r < beads.count; r++) {
            if (beads.get(r).uid === uid) {
                beads.remove(r);
                return ;
            }
        }
    }

    implicitWidth: row.width
    implicitHeight: Math.ceil(echo.dot * 2.6)
    clip: true
    onTextChanged: echo.sync()
    Component.onCompleted: echo.sync()

    NumberAnimation on wave {
        running: (echo.busy || echo.swell > 0) && echo.visible
        from: 0
        to: 1
        duration: Theme.ms(1100)
        loops: Animation.Infinite
    }

    ListModel {
        id: beads
    }

    // длинный секрет показывает свой новый конец
    Row {
        id: row

        x: Math.min(0, echo.width - row.width)
        height: echo.height

        Repeater {
            model: beads

            Item {
                id: bead

                required property int uid
                required property string shape
                required property real tilt
                required property real turn
                required property int lag
                required property int at
                required property string ghost
                required property bool hold
                required property bool dying
                // слот раскрывается под фигуру, затем затягивается вокруг точки
                property real grow: 0
                property real pop: 0
                property real lit: 0
                property real melt: 0
                property real settle: 0
                property real twist: 0
                property real gone: 0
                property real shut: 0
                // выбранное: точка квадратнеет, а за ней заливается полоса
                property real pick: 0
                property real shown: echo.reveal ? 1 : 0
                readonly property bool chosen: bead.at >= 0 && bead.at >= echo.selectionStart && bead.at < echo.selectionEnd
                readonly property bool opens: bead.at === echo.selectionStart
                readonly property bool closes: bead.at === echo.selectionEnd - 1
                readonly property real spin: bead.tilt + bead.turn * bead.twist
                // квадрат стоит ровно лишь на четверть-обороте
                readonly property real square: bead.spin - Math.round(bead.spin / 90) * 90
                readonly property color ink: Qt.tint(echo.tint, Theme.alpha(echo.picked, bead.pick))
                readonly property string glyph: bead.at >= 0 ? echo.text.charAt(bead.at) : bead.ghost
                readonly property real bob: bead.at < 0 ? 0 : echo.swell * Math.pow(Math.max(0, Math.sin((echo.wave - bead.at * 0.09) * 2 * Math.PI)), 2)
                readonly property real pitch: echo.dot + echo.gap
                readonly property real face: metrics.advanceWidth + echo.gap / 3

                width: (bead.pitch + (bead.face - bead.pitch) * bead.shown) * bead.grow * (1 - bead.shut)
                height: row.height
                onDyingChanged: {
                    if (!bead.dying)
                        return ;

                    life.stop();
                    picking.stop();
                    death.start();
                }
                // выбор проходит вдоль ряда; отпускание — всё разом
                onChosenChanged: {
                    if (bead.dying)
                        return ;

                    picking.stop();
                    pickTo.to = bead.chosen ? 1 : 0;
                    pickWait.duration = bead.chosen ? Math.min(Theme.ms(260), (bead.at - echo.selectionStart) * Theme.ms(22)) : 0;
                    picking.start();
                }
                Component.onCompleted: life.start()

                TextMetrics {
                    id: metrics

                    font: echo.font
                    text: echo.reveal || bead.shown > 0 ? bead.glyph : ""
                }

                // один комок на бусину, сливающийся в полосу с круглыми концами
                Rectangle {
                    readonly property real r: height / 2

                    anchors.centerIn: parent
                    width: (parent.width + 1) * bead.pick
                    height: echo.dot * 2 * (0.55 + 0.45 * bead.pick)
                    topLeftRadius: bead.opens ? r : r * (1 - bead.pick)
                    bottomLeftRadius: bead.opens ? r : r * (1 - bead.pick)
                    topRightRadius: bead.closes ? r : r * (1 - bead.pick)
                    bottomRightRadius: bead.closes ? r : r * (1 - bead.pick)
                    color: echo.band
                    opacity: bead.lit * (1 - bead.gone)
                    visible: bead.pick > 0
                }

                // бусина слишком мала для curve-рендера, который оставляет рваный
                // край, поэтому контур тесселируется и мультисэмплируется
                Item {
                    id: form

                    readonly property real size: echo.dot * 1.5

                    width: form.size
                    height: form.size
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -bead.bob * Theme.dp(3)
                    layer.enabled: true
                    layer.samples: 8
                    layer.smooth: true
                    rotation: bead.spin - bead.square * bead.pick
                    scale: bead.pop * (1 - bead.settle / 3) * (1 - bead.gone / 2) * (1 - bead.shown / 2) * (1 + bead.bob / 4) * (1 - 0.12 * bead.pick + 0.3 * Math.sin(Math.PI * bead.pick))
                    opacity: bead.lit * (1 - bead.gone) * (1 - bead.shown)
                    visible: opacity > 0

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.GeometryRenderer

                        ShapePath {
                            fillColor: bead.ink
                            strokeColor: "transparent"
                            strokeWidth: 0

                            PathSvg {
                                path: Shapes.svg(Shapes.mix(Shapes.mix(Shapes.radii(bead.shape), Shapes.radii("circle"), bead.melt), Shapes.radii("square"), bead.pick), form.size, 0)
                            }

                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -bead.bob * Theme.dp(3)
                    text: bead.glyph
                    font: echo.font
                    color: bead.ink
                    scale: (0.6 + 0.4 * bead.shown) * (1 - bead.gone / 2)
                    opacity: bead.lit * bead.shown * (1 - bead.gone)
                    visible: opacity > 0
                }

                SequentialAnimation {
                    id: picking

                    PauseAnimation {
                        id: pickWait
                    }

                    NumberAnimation {
                        id: pickTo

                        target: bead
                        property: "pick"
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveEffects
                    }

                }

                ParallelAnimation {
                    id: life

                    SequentialAnimation {
                        PauseAnimation {
                            duration: bead.lag
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: bead
                                property: "lit"
                                to: 1
                                duration: Theme.durDefaultEffects
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveEffects
                            }

                            NumberAnimation {
                                target: bead
                                property: "pop"
                                to: 1
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                            NumberAnimation {
                                target: bead
                                property: "grow"
                                to: 1.3
                                duration: Theme.durDefaultEffects
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveEffects
                            }

                        }

                        PauseAnimation {
                            duration: Theme.ms(180)
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: bead
                                property: "melt"
                                to: 1
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                            NumberAnimation {
                                target: bead
                                property: "settle"
                                to: 1
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                            NumberAnimation {
                                target: bead
                                property: "grow"
                                to: 1
                                duration: Theme.durDefaultEffects
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveEffects
                            }

                        }

                    }

                    SequentialAnimation {
                        PauseAnimation {
                            duration: bead.lag
                        }

                        NumberAnimation {
                            target: bead
                            property: "twist"
                            to: 1
                            duration: Theme.ms(900)
                            easing.type: Easing.OutSine
                        }

                    }

                }

                ParallelAnimation {
                    id: death

                    onFinished: Qt.callLater(echo.bury, bead.uid)

                    NumberAnimation {
                        target: bead
                        property: "gone"
                        to: 1
                        duration: Theme.durDefaultEffects
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveEffects
                    }

                    SequentialAnimation {
                        PauseAnimation {
                            duration: bead.hold ? Theme.durDefaultEffects : 0
                        }

                        NumberAnimation {
                            target: bead
                            property: "shut"
                            to: 1
                            duration: Theme.durMedium
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                }

                Behavior on shown {
                    NumberAnimation {
                        duration: Theme.durDefaultEffects
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveEffects
                    }

                }

            }

        }

    }

    Rectangle {
        width: Theme.dp(18)
        height: echo.height
        opacity: Math.min(1, -row.x / Theme.dp(18))
        visible: row.x < 0

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: echo.edge
            }

            GradientStop {
                position: 1
                color: Theme.alpha(echo.edge, 0)
            }

        }

    }

    Behavior on tint {
        ColorAnimation {
            duration: Theme.durShort
        }

    }

    Behavior on swell {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

}
