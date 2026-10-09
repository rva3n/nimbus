import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3-карточка уведомления: иконка в контейнере, текст и кнопка закрытия.
Item {
    id: ni

    property var item: null
    property int itemIndex: 0

    implicitHeight: Math.max(Theme.dp(64), niLayout.implicitHeight + Theme.dp(24))

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.bgTile
    }

    RowLayout {
        id: niLayout

        anchors.fill: parent
        anchors.margins: Theme.dp(12)
        spacing: Theme.dp(12)

        Rectangle { // контейнер иконки
            Layout.alignment: Qt.AlignTop
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.radiusPill
            color: Theme.accentContainer

            Icon {
                anchors.centerIn: parent
                name: "notifications"
                size: Theme.dp(20)
                color: Theme.fgAccentContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(2)

            Text { // appName · summary
                Layout.fillWidth: true
                text: (ni.item && ni.item.appName ? ni.item.appName + " · " : "") + (ni.item ? (ni.item.summary || "") : "")
                color: Theme.text
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("titleSmall")
                font.weight: Theme.typeWeight("titleSmall")
            }

            Text { // тело
                Layout.fillWidth: true
                visible: text !== ""
                text: ni.item ? (ni.item.body || "") : ""
                color: Theme.subtext
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            icon: "close"
            size: "s"
            onClicked: Notif.dismissAt(ni.itemIndex)
        }
    }
}
