import QtQuick
import "../core"

// M3 Expressive слайдер (порт lucidui/Slider.qml): bar-ручка, отделённая от
// трека зазором, стоп-точка на конце и — на крупных размерах — глиф в активном
// треке. Размеры xs/s/m/l: трек 14/22/38/52dp, ручка 36/50/64dp; ручка
// 4dp→6dp (ховер/нажатие)→2dp (покой) со стадионными торцами; внешний радиус
// трека trackH/2, gap dp(5), внутренний dp(2); ховер растит трек и ручку на
// dp(2); пузырь значения inverseSurface, радиус dp(15), scale от 0.6
// (curveFastSpatial); эластичный live curveStandard @ durFastSpatial.
//
// Nimbus: сохранён публичный API прежнего слайдера (value/live/dragging/icon,
// moved/committed/iconClicked). Старый «yoru»-стиль (толстый трек, тонкая
// риска, иконка внутри заливки) заменён. `icon` теперь рисуется ведущим
// бейджем-глифом (как в lucidosd/Osd.qml), иначе на дефолтном размере xs
// (трек 14dp) глиф в треке не помещался бы и иконка/iconClicked терялись.
Item {
    id: sl

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    // "xs" | "s" | "m" | "l"
    property string size: "xs"
    property string icon: ""
    property bool disabled: false
    property bool showValue: true
    // показания едут на конце заливки, а не снаружи трека
    property bool inlineValue: false
    readonly property alias valueItem: valueLabel
    property var valueText: null
    property color activeColor: Theme.primary
    property color inactiveColor: Theme.secondaryContainer
    readonly property bool dragging: area.pressed
    readonly property bool hovered: area.containsMouse
    // значение во время перетаскивания, до фиксации
    property real live: sl.value
    // плавно доводит значение, пришедшее извне (клавишей/другим контролом);
    // никогда не пока указатель источник
    property bool easeValue: true
    // перетаскивание, которым слайдер не владеет (карточка-подсказка бара):
    // она пишет live сама, поэтому value не тянет live назад, пока не отпустят
    property bool held: false

    property bool iconClickable: false

    signal moved(real value)
    signal released(real value)
    // nimbus-имя прежнего сигнала (эмитится вместе с released на отпускании)
    signal committed(real value)
    signal iconClicked()

    // метрики следуют размерному токену, если вызывающий не переопределил их
    property int trackH: sl.size === "l" ? Theme.dp(52) : (sl.size === "m" ? Theme.dp(38) : (sl.size === "s" ? Theme.dp(22) : Theme.dp(14)))
    property int handleH: sl.size === "l" ? Theme.dp(64) : (sl.size === "m" ? Theme.dp(50) : Theme.dp(36))
    property real outerR: sl.size === "l" ? Theme.dp(16) : (sl.size === "m" ? Theme.dp(12) : sl.trackH / 2)
    property int iconSize: Theme.dp(20)
    // указатель распирает контрол, а не просто тонирует
    property int hoverGrow: Theme.dp(2)
    // выключен и через legacy `enabled`, и через `disabled`
    readonly property bool _off: sl.disabled || !sl.enabled
    readonly property bool hot: !sl._off && (sl.hovered || sl.dragging)
    readonly property int trackHNow: sl.trackH + (sl.hot ? sl.hoverGrow : 0)
    readonly property int handleHNow: sl.handleH + (sl.hot ? sl.hoverGrow * 2 : 0)
    // стадионный торец должен оставаться стадионом при росте
    readonly property real outerRNow: sl.outerR >= sl.trackH / 2 ? sl.trackHNow / 2 : sl.outerR
    readonly property int handleW: area.pressed ? Theme.dp(2) : (sl.hot ? Theme.dp(6) : Theme.dp(4))
    readonly property int gap: Theme.dp(5)
    readonly property real innerR: Theme.dp(2)

    // ведущий бейдж под `icon` (nimbus): глиф dp(18) внутри фигуры dp(36)
    readonly property bool hasBadge: sl.icon !== ""
    readonly property int badgeSize: Theme.dp(36)
    readonly property int badgeGap: Theme.dp(12)
    // трек начинается после бейджа
    readonly property int contentX: sl.hasBadge ? sl.badgeSize + sl.badgeGap : 0
    readonly property real contentW: Math.max(0, sl.width - sl.contentX)
    readonly property real frac: sl.to > sl.from ? Math.max(0, Math.min(1, (sl.live - sl.from) / (sl.to - sl.from))) : 0
    readonly property real handleX: sl.contentX + sl.handleW / 2 + sl.frac * Math.max(0, sl.contentW - sl.handleW)

    function snap(v) {
        var c = Math.max(sl.from, Math.min(sl.to, v));
        if (sl.stepSize > 0)
            c = sl.from + Math.round((c - sl.from) / sl.stepSize) * sl.stepSize;

        return c;
    }

    function valueAt(px) {
        var f = Math.max(0, Math.min(1, (px - sl.contentX - sl.handleW / 2) / Math.max(1, sl.contentW - sl.handleW)));
        return sl.snap(sl.from + f * (sl.to - sl.from));
    }

    onValueChanged: {
        if (!area.pressed && !sl.held)
            sl.live = sl.value;

    }

    Behavior on live {
        enabled: sl.easeValue && !area.pressed && !sl.held

        NumberAnimation {
            duration: Theme.durFastSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveStandard
        }

    }

    implicitWidth: Theme.dp(200)
    implicitHeight: Math.max(sl.handleH, Math.max(sl.trackH, sl.hasBadge ? sl.badgeSize : 0))
    opacity: sl._off ? Theme.disabledContent : 1

    // ── ведущий бейдж иконки ───────────────────────────────────────────
    Item {
        id: badge

        visible: sl.hasBadge
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: sl.badgeSize
        height: sl.badgeSize

        MaterialShape {
            anchors.fill: parent
            shape: "cookie9"
            color: sl.hot ? sl.activeColor : Theme.withBlur(Theme.mHighest)
            rotation: sl.hot ? 20 : 0

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durSlowSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        Icon {
            anchors.centerIn: parent
            name: sl.icon
            size: Theme.dp(18)
            fill: sl.hot ? 1 : 0
            color: sl.hot ? Theme.fgPrimary : Theme.text
        }

        MouseArea {
            anchors.fill: parent
            enabled: !sl._off
            cursorShape: Qt.PointingHandCursor
            onClicked: sl.iconClicked()
        }

    }

    // ── активный трек (до ручки) ───────────────────────────────────────
    Rectangle {
        id: active

        x: sl.contentX
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, sl.handleX - sl.handleW / 2 - sl.gap - sl.contentX)
        height: sl.trackHNow
        color: sl.activeColor
        visible: width > 0.5
        topLeftRadius: sl.outerRNow
        bottomLeftRadius: sl.outerRNow
        topRightRadius: sl.innerR
        bottomRightRadius: sl.innerR

        Behavior on height {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    // ── неактивный трек (после ручки) ──────────────────────────────────
    Rectangle {
        id: inactive

        anchors.verticalCenter: parent.verticalCenter
        x: sl.handleX + sl.handleW / 2 + sl.gap
        width: Math.max(0, sl.contentX + sl.contentW - x)
        height: sl.trackHNow
        color: sl.inactiveColor
        visible: width > 0.5
        topRightRadius: sl.outerRNow
        bottomRightRadius: sl.outerRNow
        topLeftRadius: sl.innerR
        bottomLeftRadius: sl.innerR

        Behavior on height {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Rectangle {
            anchors.fill: parent
            topRightRadius: sl.outerRNow
            bottomRightRadius: sl.outerRNow
            topLeftRadius: sl.innerR
            bottomLeftRadius: sl.innerR
            color: Theme.text
            opacity: sl.hot ? Theme.stateHover : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Math.max(Theme.dp(3), (sl.trackHNow - Theme.dp(4)) / 2)
            width: Theme.dp(4)
            height: Theme.dp(4)
            radius: Theme.dp(2)
            color: sl.activeColor
            visible: parent.width > 14
        }

    }

    // ── bar-ручка ──────────────────────────────────────────────────────
    Rectangle {
        id: handle

        x: sl.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: sl.handleW
        height: sl.handleHNow
        radius: width / 2
        color: sl.activeColor

        Behavior on width {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    // читаемое значение на конце заливки (inlineValue)
    LText {
        id: valueLabel

        readonly property real pad: Math.max(Theme.dp(8), sl.trackH / 4)
        readonly property bool onActive: active.width - valueLabel.pad * 2 >= valueLabel.implicitWidth

        visible: sl.inlineValue
        anchors.verticalCenter: parent.verticalCenter
        x: valueLabel.onActive ? sl.contentX + active.width - valueLabel.pad - valueLabel.implicitWidth : inactive.x + valueLabel.pad
        role: "titleMedium"
        weight: 640
        rounded: 100
        tabular: true
        color: valueLabel.onActive ? Theme.fgPrimary : Theme.fgSecondaryContainer
        text: sl.valueText ? sl.valueText(sl.live) : Math.round(sl.frac * 100) + "%"
    }

    // пузырь значения над ручкой
    Rectangle {
        id: bubble

        visible: sl.showValue && opacity > 0.01
        opacity: area.pressed ? 1 : 0
        scale: area.pressed ? 1 : 0.6
        transformOrigin: Item.Bottom
        width: Math.max(Theme.dp(36), label.implicitWidth + Theme.dp(20))
        height: Theme.dp(30)
        radius: Theme.dp(15)
        color: Theme.inverseSurface
        x: sl.handleX - width / 2
        y: -height - Theme.dp(8)

        LText {
            id: label

            anchors.centerIn: parent
            role: "labelLarge"
            color: Theme.fgInverseSurface
            text: sl.valueText ? sl.valueText(sl.live) : Math.round(sl.frac * 100)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

    // зона перетаскивания — только трек (бейдж перехватывает свои клики сам)
    MouseArea {
        id: area

        x: sl.contentX
        width: sl.contentW
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: -Theme.dp(6)
        anchors.bottomMargin: -Theme.dp(6)
        enabled: !sl._off
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (mouse) => {
            sl.live = sl.valueAt(mouse.x + sl.contentX);
            sl.moved(sl.live);
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return ;

            sl.live = sl.valueAt(mouse.x + sl.contentX);
            sl.moved(sl.live);
        }
        onReleased: {
            sl.released(sl.live);
            sl.committed(sl.live);
        }
        onWheel: (wheel) => {
            var step = sl.stepSize > 0 ? sl.stepSize : (sl.to - sl.from) / 20;
            var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            sl.live = sl.snap(sl.value + (d > 0 ? step : -step));
            sl.moved(sl.live);
            sl.released(sl.live);
            sl.committed(sl.live);
        }
    }

    // клик по глифу поверх трека (если бейджа нет, но iconClickable включён)
    MouseArea {
        visible: sl.iconClickable && !sl.hasBadge
        x: sl.contentX - Theme.dp(8)
        y: 0
        width: Theme.dp(24) + Theme.dp(16)
        height: sl.height
        cursorShape: Qt.PointingHandCursor
        onClicked: sl.iconClicked()
    }

}
