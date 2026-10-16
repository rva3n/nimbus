import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Совместимая строка устройства на ui/ListItem: position формирует групповые
// углы, а дополнительные элементы остаются доступны через trailing.
Item {
    id: dr

    property string devName: ""
    property string icon: ""
    property string sub: ""
    property bool selected: false
    property string position: "single"
    property alias headline: dr.devName
    property alias trailing: extraTrail.data
    readonly property real outerRadius: Theme.rad(20)
    readonly property real innerRadius: Theme.rad(5)

    signal clicked()

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.dp(56)

    ListItem {
        id: row

        anchors.fill: parent
        headline: dr.devName
        supporting: dr.sub
        supportingRole: "bodySmall"
        selected: dr.selected
        position: dr.position
        containerColor: "transparent"
        leadingVisible: dr.icon !== ""
        leadingMargin: Theme.dp(14)
        textStartMargin: Theme.dp(14)
        leadingTextSpacing: Theme.dp(12)
        textTrailingSpacing: Theme.dp(12)
        trailingSpacing: Theme.dp(12)
        stateTint: dr.selected ? Theme.fgSecondaryContainer : Theme.text
        outerRadius: dr.outerRadius
        innerRadius: dr.innerRadius
        onClicked: dr.clicked()

        leading: Rectangle {
            anchors.fill: parent
            visible: dr.icon !== ""
            radius: Theme.rad(12)
            color: dr.selected ? Theme.alpha(Theme.fgSecondaryContainer, 0.10) : Theme.bgTrack

            Behavior on color {
                ColorAnimation { duration: Theme.durDefaultEffects }
            }

            Icon {
                anchors.centerIn: parent
                name: dr.icon
                size: Theme.dp(22)
                fill: dr.selected ? 1 : 0
                color: dr.selected ? Theme.fgSecondaryContainer : Theme.subtext

                Behavior on color {
                    ColorAnimation { duration: Theme.durDefaultEffects }
                }
            }
        }

        trailing: Row {
            spacing: Theme.dp(12)

            Row {
                id: extraTrail
                spacing: Theme.dp(8)
            }

            Icon {
                visible: dr.selected
                name: "check"
                size: Theme.dp(20)
                fill: 1
                color: Theme.fgSecondaryContainer
            }
        }
    }
}
