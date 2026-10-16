import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Совместимая обёртка над ui/ListItem: checked остаётся источником правды,
// а toggled(bool) сообщает предполагаемое новое значение.
Item {
    id: tr

    property string label: ""
    property string sub: ""
    property string icon: ""
    property bool checked: false
    property alias active: tr.checked

    signal toggled(bool value)

    function _emit(v) {
        tr.toggled(v);
    }

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(Theme.dp(tr.sub !== "" ? 64 : 56), row.implicitHeight)

    ListItem {
        id: row

        anchors.fill: parent
        headline: tr.label
        supporting: tr.sub
        supportingRole: "bodySmall"
        containerColor: "transparent"
        leadingVisible: tr.icon !== ""
        leadingMargin: Theme.dp(12)
        textStartMargin: Theme.dp(12)
        leadingTextSpacing: Theme.dp(12)
        textSpacing: Theme.dp(2)
        textTrailingSpacing: Theme.dp(12)
        trailingMargin: Theme.dp(12)
        stateTint: tr.checked ? Theme.primary : Theme.text
        outerRadius: Theme.radiusMd
        innerRadius: Theme.radiusMd
        onClicked: tr._emit(!tr.checked)

        leading: Rectangle {
            anchors.fill: parent
            visible: tr.icon !== ""
            radius: Theme.rad(12)
            color: tr.checked ? Theme.accentContainer : Theme.bgTrack

            Behavior on color {
                ColorAnimation { duration: Theme.durDefaultEffects }
            }

            Icon {
                anchors.centerIn: parent
                name: tr.icon
                size: Theme.dp(22)
                fill: tr.checked ? 1 : 0
                color: tr.checked ? Theme.fgAccentContainer : Theme.subtext

                Behavior on color {
                    ColorAnimation { duration: Theme.durDefaultEffects }
                }
            }
        }

        trailing: Switch {
            checked: tr.checked
            onToggled: (v) => tr._emit(v)
        }
    }
}
