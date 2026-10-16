import QtQuick
import QtQuick.Layouts
import "../core"

// Групповая M3-карточка: заполненный контейнер Lucid-анатомии
// (Theme.mHigh, радиус shapeLgInc), необязательный заголовок и
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

    // анатомия карточки Lucid: плоский контейнер без обводки
    radius: Theme.shapeLgInc
    // фиксированная поверхность карточки, без зависимости от размытия фона
    color: Theme.mHigh
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

            LText {
                text: card.title
                visible: card.title !== ""
                role: "labelLarge"
                color: Theme.subtext
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
