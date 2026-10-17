import QtQuick
import "../core"

// Кольцевой индикатор (системные метрики и т.п.): дорожка + дуга значения.
// В центре — либо ui/Icon (icon), либо крупная подпись (label) с caption.
Item {
    id: ring

    property real value: 0                  // 0..1
    property real thickness: Theme.dp(7)
    property color color: Theme.accent
    property color trackColor: Theme.bgTrack
    property string icon: ""
    property string label: ""
    property string caption: ""

    implicitWidth: Theme.dp(88)
    implicitHeight: Theme.dp(88)

    Canvas {
        id: cv
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const cx = width / 2;
            const cy = height / 2;
            const r = Math.max(1, Math.min(width, height) / 2 - ring.thickness / 2);
            ctx.lineWidth = ring.thickness;
            ctx.lineCap = "round";

            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = ring.trackColor;
            ctx.stroke();

            const v = Math.max(0, Math.min(1, ring.value));
            if (v > 0.002) {
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * v);
                ctx.strokeStyle = ring.color;
                ctx.stroke();
            }
        }
    }

    Connections {
        target: ring

        function onValueChanged() { cv.requestPaint() }
        function onColorChanged() { cv.requestPaint() }
        function onTrackColorChanged() { cv.requestPaint() }
        function onThicknessChanged() { cv.requestPaint() }
        function onWidthChanged() { cv.requestPaint() }
        function onHeightChanged() { cv.requestPaint() }
    }

    // плавное движение значения
    Behavior on value {
        NumberAnimation {
            duration: Theme.ms(420)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }
    }

    Icon {
        anchors.centerIn: parent
        visible: ring.icon !== ""
        name: ring.icon
        size: Theme.dp(20)
        color: Theme.subtext
    }

    Column {
        anchors.centerIn: parent
        visible: ring.icon === "" && ring.label !== ""
        spacing: 0

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.label
            role: "titleLarge"
            color: Theme.text
        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ring.caption !== ""
            text: ring.caption
            role: "labelSmall"
            color: Theme.subtext
        }
    }
}
