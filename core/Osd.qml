pragma Singleton
import QtQuick
import Quickshell

// Transient on-screen displays (volume / brightness).
Singleton {
    id: root

    property bool visible: false
    property string kind: "volume"   // volume | brightness
    property real value: 0           // 0..1
    property bool muted: false

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.visible = false
    }

    function show(k, v, m) {
        root.kind = k;
        root.value = Math.max(0, Math.min(1, v));
        root.muted = !!m;
        root.visible = true;
        hideTimer.restart();
    }
}
