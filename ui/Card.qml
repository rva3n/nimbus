import QtQuick
import QtQuick.Layouts
import "../core"

// Групповая M3-карточка: заполненный контейнер, необязательный заголовок и
// действие справа. Контент по умолчанию кладётся в ColumnLayout.
//   Card { Layout.fillWidth: true; title: "Сети"; actionIcon: "refresh"
//          onActionClicked: ...; RowLayout { ... } }
Rectangle {
    id: card

    property string title: ""
    property string actionIcon: ""
    signal actionClicked()
    property real pad: Theme.dp(14)
    readonly property bool hasHeader: title !== "" || actionIcon !== ""

    default property alias content: layout.data

    radius: Theme.radiusXl
    // со «стеклом» карточки тоже чуть прозрачные, фон под ними размывает композитор
    color: Theme.blurAmount > 0 ? Theme.withBlur(Theme.mHigh) : Theme.mHigh
    border.width: 1
    border.color: Theme.a(Theme.outline, 0.25)
    implicitWidth: Theme.dp(300)
    implicitHeight: layout.implicitHeight + pad * 2
    clip: true

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.pad
        spacing: Theme.dp(4)

        RowLayout {
            visible: card.hasHeader
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.dp(4)
            spacing: Theme.dp(8)

            Text {
                text: card.title
                visible: card.title !== ""
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelLarge")
                font.weight: Theme.typeWeight("labelLarge")
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
                visible: card.title === ""
            }

            IconButton {
                visible: card.actionIcon !== ""
                icon: card.actionIcon
                size: "s"
                onClicked: card.actionClicked()
            }
        }
    }
}
