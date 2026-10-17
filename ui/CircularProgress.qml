import QtQuick
import QtQuick.Shapes
import "../core"

// M3 Expressive круговой прогресс (порт lucidui/CircularProgress.qml): волнистая
// активная дуга, простая дорожка, разделённые зазором. value 0..1.
// Центральный слот `content` принимает Icon/подпись; обычные children тоже
// рисуются поверх (anchors.centerIn: parent).
Item {
    id: cp

    property real value: 0
    property real thickness: Theme.dp(4)
    property color color: Theme.primary
    property color trackColor: Theme.secondaryContainer
    property bool showTrack: true
    // off для развёртки, которая должна следовать за источником кадр в кадр
    property bool animated: true
    property bool wavy: true
    // CircularProgressIndicatorTokens: волна 15dp глубиной 1.6dp на штрихе 4dp
    property real wavelength: cp.thickness * 3.75
    property real amplitude: cp.thickness * 0.4
    property alias content: center.data
    readonly property real gapDeg: cp._v <= 0.001 || cp._v >= 0.999 ? 0 : Math.min(18, (cp.thickness * 2 + 4) / (Math.PI * Math.max(8, cp.width)) * 360)
    property real _v: Math.max(0, Math.min(1, cp.value))
    readonly property real _radius: (Math.min(cp.width, cp.height) - cp.thickness) / 2
    readonly property real _circumference: 2 * Math.PI * Math.max(1, cp._radius)
    // целое число волн замыкает волну на себе; зажато, чтобы широкая дуга не читалась шумом
    readonly property int waveCount: Math.max(6, Math.min(14, Math.round(cp._circumference / Math.max(1, cp.wavelength))))
    // m3 задаёт волнистый индикатор на 48dp; ниже примерно половины этого волна читается шумом
    readonly property bool _waveOn: cp.wavy && cp.amplitude > 0.3 && Math.min(cp.width, cp.height) >= Theme.dp(36)
    // волне нужна дуга, чтобы жить, поэтому она входит плавно за первые полторы длины волны
    readonly property real _ampTarget: {
        if (!cp._waveOn)
            return 0;

        const span = cp._v * cp.waveCount;
        return Math.max(0, Math.min(1, (span - 0.75) / 0.75));
    }
    property real _amp: cp._ampTarget
    // 14 точек на цикл — предел, после которого ломаная перестаёт читаться гранёной
    readonly property int _steps: Math.max(16, cp.waveCount * 14)

    // полный оборот фиксированным угловым шагом в единичных терминах: двигает его
    // только счётчик волн, поэтому растущая развёртка просто берёт длинный срез таблицы
    readonly property var _table: {
        const n = cp._steps;
        const ca = new Array(n + 1);
        const sa = new Array(n + 1);
        const rs = new Array(n + 1);
        const k = cp.waveCount;
        for (let i = 0; i <= n; i++) {
            const ang = (-90 + 360 * (i / n)) * Math.PI / 180;
            ca[i] = Math.cos(ang);
            sa[i] = Math.sin(ang);
            // фаза обнулена на 12 часах, чтобы дуга стартовала вровень с окружностью
            rs[i] = Math.sin(k * (ang + Math.PI / 2));
        }
        return {
            "ca": ca,
            "sa": sa,
            "rs": rs
        };
    }

    function _wavePoints() {
        if (!cp._waveOn || cp._v <= 0.001)
            return [];

        const t = cp._table;
        const cx = cp.width / 2;
        const cy = cp.height / 2;
        const r = cp._radius;
        const a = cp.amplitude * cp._amp;
        const n = cp._steps;
        // целые шаги внутри развёртки, затем конечная точка ровно на ней
        const full = Math.floor(cp._v * n);
        const pts = new Array(full + 2);
        for (let i = 0; i <= full; i++) {
            const rr = r + a * t.rs[i];
            pts[i] = Qt.point(cx + t.ca[i] * rr, cy + t.sa[i] * rr);
        }
        const ang = (-90 + cp._v * 360) * Math.PI / 180;
        const rr = r + a * Math.sin(cp.waveCount * (ang + Math.PI / 2));
        pts[full + 1] = Qt.point(cx + Math.cos(ang) * rr, cy + Math.sin(ang) * rr);
        return pts;
    }

    implicitWidth: Theme.dp(40)
    implicitHeight: Theme.dp(40)

    Behavior on _v {
        enabled: cp.animated

        NumberAnimation {
            duration: Theme.durSlowEffects
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

    }

    Behavior on _amp {
        NumberAnimation {
            duration: Theme.durSlowEffects
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: cp.showTrack && cp._v < 0.999 ? cp.trackColor : "transparent"
            strokeWidth: cp.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: cp.width / 2
                centerY: cp.height / 2
                radiusX: cp._radius
                radiusY: cp._radius
                startAngle: -90 + cp._v * 360 + cp.gapDeg
                sweepAngle: Math.max(0, (1 - cp._v) * 360 - cp.gapDeg * 2)
            }

        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: cp._v > 0.001 && !cp._waveOn ? cp.color : "transparent"
            strokeWidth: cp.thickness
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: cp.width / 2
                centerY: cp.height / 2
                radiusX: cp._radius
                radiusY: cp._radius
                startAngle: -90
                sweepAngle: cp._v * 360
            }

        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: cp._v > 0.001 && cp._waveOn ? cp.color : "transparent"
            strokeWidth: cp.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: cp._wavePoints()
            }

        }

    }

    // центральный слот: содержимое кладётся поверх дуги
    Item {
        id: center

        anchors.fill: parent
    }

}
