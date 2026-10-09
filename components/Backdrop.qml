import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Full-screen invisible click-catcher: closes the island panel/launcher when
// clicking outside. Lives on the Top layer, below the Overlay island.
PanelWindow {
    id: root
    required property var modelData
    property bool active: false
    property var shell: null

    screen: modelData
    visible: active
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nimbus-backdrop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.shell) root.shell.closeOverlays()
    }
}
