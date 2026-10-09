import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3 list item: label + sub слева, Switch справа.
Rectangle {
    id: tr
    property string label: ""
    property string sub: ""
    property bool active: false
    signal toggled()
    implicitHeight: Theme.dp(56)
    radius: Theme.radiusLg
    color: Theme.bgTile
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(16)
        anchors.rightMargin: Theme.dp(16)
        spacing: Theme.dp(12)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodyLarge")
                font.weight: Theme.typeWeight("bodyLarge"); color: Theme.text
                text: tr.label
            }
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight
                visible: tr.sub !== ""
                font.family: Theme.textFont; font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall"); color: Theme.subtext
                text: tr.sub
            }
        }
        Switch {
            id: sw
            checked: tr.active
            onToggled: tr.toggled()
        }
    }
    // Switch при клике инвертирует checked сам (ломает биндинг) — подтягиваем
    // состояние из active, когда оно меняется (в т.ч. опросом nmcli/bluetoothctl)
    onActiveChanged: sw.checked = tr.active
}
