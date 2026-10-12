import QtQuick
import "../core"

// Одна строка текста на типографической шкале, что дрейфует вбок, когда не
// помещается, отдыхая в начале между проходами (порт lucidui/Marquee.qml).
// Текст стоит на месте, если помещается или прокрутка выключена.
Item {
    id: mq

    property string text: ""
    property string role: "bodyMedium"
    property real weight: Theme.typeWeight(mq.role)
    property color color: Theme.text
    property bool scrolling: true
    // пикселей в секунду
    property real speed: 34
    readonly property real gap: Theme.dp(48)
    readonly property bool overflowing: probe.implicitWidth > mq.width + 1
    readonly property bool moving: mq.scrolling && mq.overflowing && mq.visible
    property real offset: 0

    implicitHeight: Math.ceil(probe.implicitHeight)
    clip: mq.overflowing
    onMovingChanged: mq.offset = 0
    onTextChanged: {
        mq.offset = 0;
        if (drift.running)
            drift.restart();

    }

    LText {
        id: probe

        visible: false
        role: mq.role
        weight: mq.weight
        text: mq.text
    }

    Row {
        x: -mq.offset
        spacing: mq.gap

        LText {
            width: mq.overflowing && mq.scrolling ? probe.implicitWidth : mq.width
            role: mq.role
            weight: mq.weight
            color: mq.color
            text: mq.text
            elide: mq.overflowing && !mq.scrolling ? Text.ElideRight : Text.ElideNone
        }

        LText {
            visible: mq.moving
            role: mq.role
            weight: mq.weight
            color: mq.color
            text: mq.text
        }

    }

    SequentialAnimation {
        id: drift

        running: mq.moving && mq.visible
        loops: Animation.Infinite

        PauseAnimation {
            duration: 2200
        }

        NumberAnimation {
            target: mq
            property: "offset"
            from: 0
            to: probe.implicitWidth + mq.gap
            duration: Math.max(1, (probe.implicitWidth + mq.gap) / mq.speed * 1000)
        }

        ScriptAction {
            script: mq.offset = 0
        }

    }

}
