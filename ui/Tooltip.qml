pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import "../core"

// Lucid-тултип: мягкая карточка withBlur(Theme.mHigh)/radiusMd с гауссовой
// тенью, текст labelSmall. Появление — после паузы ~400мс, fade OutCubic;
// исчезновение быстрее. Owner задаёт якорь: вызывает showTip(item, text) /
// hideTip(item); позиция считается один раз на момент показа (под чипом,
// по центру, с прижимом к краям родителя). Input не ловит (mask окна).
Item {
    id: root

    property string text: ""
    property bool show: false
    property Item anchorItem: null

    visible: root.opacity > 0.01
    opacity: root.shown ? 1 : 0
    width: Math.max(Theme.dp(56), body.implicitWidth + Theme.dp(24))
    height: Theme.dp(30)

    // показ/скрытие: пауза 400мс на вход (не мигаем при быстрой проводке),
    // на выходе гасим сразу и быстрее
    property bool shown: false
    readonly property int fadeIn: Theme.durFastEffects
    readonly property int fadeOut: Math.max(Theme.ms(80), Math.round(Theme.durFastEffects * 0.6))

    Timer {
        id: delayTimer
        interval: Theme.ms(400)
        onTriggered: root.shown = true
    }

    onShowChanged: {
        if (root.show) delayTimer.restart();
        else { delayTimer.stop(); root.shown = false; }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? root.fadeIn : root.fadeOut
            easing.type: Easing.OutCubic
        }
    }

    // Тень: обёртка с запасом + MultiEffect (как у капсулы острова, мягче)
    readonly property int padX: Theme.dp(14)
    readonly property int padY: Theme.dp(10)

    Item {
        id: shadowHost
        anchors.centerIn: parent
        width: root.width + root.padX * 2
        height: root.height + root.padY * 2

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: root.width
            height: root.height
            radius: Theme.radiusMd
            color: Theme.withBlur(Theme.mHigh)
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.a(Theme.scrim, 0.5)
        shadowBlur: 0.55
        shadowVerticalOffset: Theme.dp(2)
        shadowOpacity: 0.55
    }

    LText {
        id: body
        anchors.centerIn: parent
        role: "labelSmall"
        color: Theme.text
        text: root.text
    }

    // ── API для владельца ─────────────────────────────────────────────
    function showTip(item, t) {
        if (item === null || item === undefined || root.parent === null) return;
        root.anchorItem = item;
        root.text = t;
        const p = item.mapToItem(root.parent, item.width / 2, item.height);
        root.x = Math.max(Theme.dp(8),
            Math.min(p.x - root.width / 2, root.parent.width - root.width - Theme.dp(8)));
        root.y = Math.max(p.y + Theme.dp(6), 0);
        root.show = true;
    }

    function hideTip(item) {
        if (root.anchorItem === item) { root.show = false; root.anchorItem = null; }
    }
}
