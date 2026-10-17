import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../core"

// M3-строка списка на собственном контейнере (порт lucidui/ListItem.qml).
// В группе внешние углы скруглены крупно (outerRadius), а углы, стыкующиеся с
// соседом, остаются тугими (innerRadius) — это и есть signature-вид Lucid.
// Положение в группе задаётся position: top | middle | bottom | single.
Item {
    id: li

    property string headline: ""
    property string headlineRole: "bodyLarge"
    property real headlineWeight: 480
    property color headlineColor: Theme.text
    property int headlineLines: 1
    property int headlineWrapMode: Text.NoWrap
    property string supporting: ""
    property string supportingRole: "bodyMedium"
    property string overline: ""
    property string icon: ""
    // удобные алиасы под имена из ТЗ
    property alias text: li.headline
    property alias subtext: li.supporting
    property alias description: li.supporting
    property alias leadingIcon: li.icon
    property real iconFill: 0
    property color iconColor: Theme.subtext
    property color containerColor: Theme.surface
    property bool first: true
    property bool last: true
    // положение в группе; пусто — используется first/last напрямую
    property string position: ""
    property bool clickable: true
    property bool selected: false
    property bool disabled: false
    property bool leadingVisible: true
    property int supportingLines: 1
    property real outerRadius: Theme.dp(20)
    property real innerRadius: Theme.dp(5)
    property real leadingMargin: Theme.dp(14)
    property real textStartMargin: Theme.dp(18)
    property real leadingTextSpacing: Theme.dp(12)
    property real textSpacing: Theme.dp(1)
    property real textTrailingSpacing: Theme.dp(12)
    property real trailingMargin: Theme.dp(16)
    property real trailingSpacing: Theme.dp(8)
    property real headlineTrailingSpacing: Theme.dp(7)
    property bool headlineTrailingVisible: true
    property real stateHoverOpacity: Theme.stateHover
    property real statePressOpacity: Theme.statePressed
    property int colorTransitionDuration: Theme.durDefaultEffects
    property real borderWidth: 0
    property color borderColor: Theme.outline
    property color stateTint: Theme.text
    property alias leading: leadSlot.data
    property alias trailing: trailSlot.data
    property alias headlineTrailing: headlineTail.data
    readonly property bool hasLeading: li.icon !== "" || (li.leadingVisible && leadSlot.children.length > 0)
    readonly property bool hasHeadlineTrailing: li.headlineTrailingVisible && headlineTail.children.length > 0
    readonly property bool hovered: li.clickable && stateLayer.active
    readonly property bool pressed: li.clickable && stateLayer.pressed
    readonly property bool _first: li.position === "" ? li.first : (li.position === "top" || li.position === "single")
    readonly property bool _last: li.position === "" ? li.last : (li.position === "bottom" || li.position === "single")

    signal clicked()

    implicitHeight: Math.max(li.supporting !== "" || li.overline !== "" ? Theme.dp(64) : Theme.dp(52), col.implicitHeight + Theme.dp(20))
    implicitWidth: Theme.dp(320)
    Layout.fillWidth: true
    opacity: li.disabled ? Theme.disabledContent : 1

    Rectangle {
        id: box

        anchors.fill: parent
        clip: true
        color: li.selected ? Theme.secondaryContainer : li.containerColor
        topLeftRadius: li._first ? li.outerRadius : li.innerRadius
        topRightRadius: li._first ? li.outerRadius : li.innerRadius
        bottomLeftRadius: li._last ? li.outerRadius : li.innerRadius
        bottomRightRadius: li._last ? li.outerRadius : li.innerRadius
        border.width: li.borderWidth
        border.color: li.borderColor

        Behavior on color {
            ColorAnimation {
                duration: li.colorTransitionDuration
            }

        }

        ClippingRectangle {
            anchors.fill: parent
            color: "transparent"
            topLeftRadius: box.topLeftRadius
            topRightRadius: box.topRightRadius
            bottomLeftRadius: box.bottomLeftRadius
            bottomRightRadius: box.bottomRightRadius

            StateLayer {
                id: stateLayer

                visible: li.clickable
                enabled: li.clickable && !li.disabled
                disabled: !li.clickable || li.disabled
                radius: li.innerRadius
                tint: li.stateTint
                hoverOpacity: li.stateHoverOpacity
                pressOpacity: li.statePressOpacity
                onClicked: li.clicked()
            }
        }

    }

    Item {
        id: leadBox

        visible: li.hasLeading
        width: li.hasLeading ? Theme.dp(40) : 0
        height: Theme.dp(40)
        anchors.left: parent.left
        anchors.leftMargin: li.leadingMargin
        anchors.verticalCenter: parent.verticalCenter

        Icon {
            visible: li.icon !== ""
            anchors.centerIn: parent
            name: li.icon
            size: Theme.dp(22)
            fill: li.selected ? 1 : li.iconFill
            color: li.selected ? Theme.fgSecondaryContainer : li.iconColor
        }

        Item {
            id: leadSlot

            anchors.fill: parent
        }

    }

    Column {
        id: col

        anchors.left: li.hasLeading ? leadBox.right : parent.left
        anchors.leftMargin: li.hasLeading ? li.leadingTextSpacing : li.textStartMargin
        anchors.right: trailSlot.left
        anchors.rightMargin: li.textTrailingSpacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: li.textSpacing

        LText {
            visible: li.overline !== ""
            width: parent.width
            text: li.overline
            role: "labelSmall"
            color: Theme.subtext
            elide: Text.ElideRight
        }

        LText {
            id: headlineLabel
            width: parent.width
            text: li.headline
            role: li.headlineRole
            weight: li.headlineWeight
            color: li.selected ? Theme.fgSecondaryContainer : li.headlineColor
            wrapMode: li.headlineWrapMode
            maximumLineCount: li.headlineLines
            elide: Text.ElideRight
            visible: !li.hasHeadlineTrailing
        }

        Row {
            id: headlineRow

            visible: li.hasHeadlineTrailing
            width: parent.width
            height: Math.max(headlineWithTrailing.implicitHeight, headlineTail.implicitHeight)
            spacing: li.headlineTrailingSpacing

            LText {
                id: headlineWithTrailing

                width: Math.max(0, headlineRow.width - headlineTail.implicitWidth - headlineRow.spacing)
                text: li.headline
                role: li.headlineRole
                weight: li.headlineWeight
                color: li.selected ? Theme.fgSecondaryContainer : li.headlineColor
                wrapMode: li.headlineWrapMode
                maximumLineCount: li.headlineLines
                elide: Text.ElideRight
            }

            Row {
                id: headlineTail

                width: implicitWidth
                height: implicitHeight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        LText {
            visible: li.supporting !== ""
            width: parent.width
            text: li.supporting
            role: li.supportingRole
            color: li.selected ? Theme.alpha(Theme.fgSecondaryContainer, 0.8) : Theme.subtext
            wrapMode: li.supportingLines > 1 ? Text.WordWrap : Text.NoWrap
            maximumLineCount: li.supportingLines
            elide: Text.ElideRight
        }

    }

    Row {
        id: trailSlot

        anchors.right: parent.right
        anchors.rightMargin: li.trailingMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: li.trailingSpacing
    }

}
