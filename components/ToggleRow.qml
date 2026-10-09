import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3 list item: ведущая иконка (опционально), label + sub слева, Switch справа.
// Строка прозрачная — живёт внутри ui/Card; ховер — bgHover, active — accent-контейнер.
Rectangle {
    id: tr
    property string label: ""
    property string sub: ""
    property bool active: false
    property string icon: ""
    signal toggled()
    implicitHeight: Theme.dp(56)
    radius: Theme.radiusMd
    color: trHover.containsMouse ? Theme.bgHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }

    // только ховер: клики отдаём Switch'у
    MouseArea {
        id: trHover
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(8)
        anchors.rightMargin: Theme.dp(8)
        spacing: Theme.dp(8)

        Rectangle { // ведущая иконка 40×40
            visible: tr.icon !== ""
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusMd
            color: tr.active ? Theme.accentContainer : Theme.bgTrack
            Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }

            Icon {
                anchors.centerIn: parent
                name: tr.icon
                size: Theme.dp(20)
                color: tr.active ? Theme.fgAccentContainer : Theme.subtext
                Behavior on color { ColorAnimation { duration: Theme.durDefaultEffects } }
            }
        }

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
