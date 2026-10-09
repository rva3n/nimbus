import QtQuick
import "../core"

Row {
    id: wsRow
    property string output: ""
    spacing: 5
    Repeater {
        model: Umbriel.workspacesFor(output)
        delegate: Rectangle {
            required property var modelData
            width: modelData.active ? 14 : 6
            height: 6; radius: 3
            color: modelData.active ? Theme.accent
                 : modelData.occupied ? Theme.a(Theme.subtext, 0.75)
                 : Theme.a(Theme.subtext, 0.3)
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }
}
