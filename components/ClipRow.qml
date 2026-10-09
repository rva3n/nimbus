import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3-строка буфера обмена внутри Card: прозрачная, hover — bgHover,
// закреплённая (selected) — accentContainer. Слева превью/иконка 40×40,
// справа pin и delete (delete — в error-тоне).
Item {
    id: cr

    property var item: null
    property bool pinned: false

    implicitHeight: Math.max(Theme.dp(56), crLayout.implicitHeight + Theme.dp(20))

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.radiusLg
        color: cr.pinned ? Theme.accentContainer
             : (crArea.pressed ? Theme.bgActive : (crArea.containsMouse ? Theme.bgHover : "transparent"))

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
    }

    MouseArea {
        id: crArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingCursor
        onClicked: cr.pinned ? Clip.copyPin(cr.item) : Clip.copy(cr.item.id, cr.item.type)
    }

    RowLayout {
        id: crLayout

        anchors.fill: parent
        anchors.margins: Theme.dp(10)
        spacing: Theme.dp(10)

        Item { // превью-картинка либо контейнер иконки 40×40
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(44)
            implicitHeight: Theme.dp(40)

            Rectangle {
                anchors.fill: parent
                visible: cr.item && cr.item.type === "image"
                radius: Theme.radiusMd
                color: Theme.bgTrack
                clip: true

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: (cr.item && cr.item.type === "image") ? ("file://" + cr.item.thumb) : ""
                }
            }

            Rectangle { // контейнер иконки
                anchors.centerIn: parent
                visible: !cr.item || cr.item.type !== "image"
                implicitWidth: Theme.dp(40)
                implicitHeight: Theme.dp(40)
                radius: Theme.radiusPill
                color: cr.pinned ? Theme.accentContainer : Theme.bgTrack

                Icon {
                    anchors.centerIn: parent
                    name: "description"
                    size: Theme.dp(20)
                    color: cr.pinned ? Theme.fgAccentContainer : Theme.subtext
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            color: cr.pinned ? Theme.fgAccentContainer : Theme.text
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
            text: cr.item ? (cr.item.type === "image" ? "Изображение"
                  : (cr.item.text !== undefined && cr.item.text !== "" ? cr.item.text : cr.item.preview)) : ""
        }

        IconButton { // pin
            Layout.alignment: Qt.AlignVCenter
            icon: "push_pin"
            size: "s"
            variant: cr.pinned ? "tonal" : "standard"
            onClicked: cr.pinned ? Clip.unpin(cr.item.id) : Clip.pin(cr.item.id)
        }

        Item { // delete в error-тоне (у ui/IconButton нет error-варианта)
            Layout.alignment: Qt.AlignVCenter
            visible: !cr.pinned
            implicitWidth: Theme.dp(32)
            implicitHeight: Theme.dp(32)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPill
                color: delArea.containsMouse || delArea.pressed ? Theme.errorContainer : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "delete"
                size: Theme.dp(18)
                color: delArea.containsMouse ? Theme.fgErrorContainer : Theme.error

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }

            MouseArea {
                id: delArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingCursor
                onClicked: Clip.del(cr.item.id)
            }
        }
    }
}
