import QtQuick
import "../core"
import "../ui"

// Специализированный таб-чип Nimbus. После перехода страницы обоев на ui/Tabs
// больше нигде не используется; оставлен для совместимости и приведён к стилю
// Lucid-чипа (rad8, выбранный — secondaryContainer, иначе прозрачный + бордер).
Item {
    id: tabBtn

    property string label: ""
    property bool active: false

    signal clicked()

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Chip {
        id: chip

        anchors.fill: parent
        label: tabBtn.label
        selected: tabBtn.active
        onClicked: tabBtn.clicked()
    }
}
