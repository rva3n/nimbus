import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3-строка буфера обмена: превью/иконка, текст в две строки, pin и delete.
Item {
    id: cr

    property var item: null
    property bool pinned: false

    implicitHeight: Math.max(Theme.dp(52), crLayout.implicitHeight + Theme.dp(20))

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.radiusLg
        color: cr.pinned ? Theme.accentContainer : Theme.bgTile

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }

        Rectangle { // state layer (ховер/нажатие)
            anchors.fill: parent
            radius: bg.radius
            color: cr.pinned ? Theme.fgAccentContainer : Theme.text
            opacity: crArea.pressed ? Theme.statePressed : (crArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Theme.easeStandard
                }
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

        Item { // превью-картинка либо иконка
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(44)
            implicitHeight: Theme.dp(32)

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

            Icon {
                anchors.centerIn: parent
                visible: !cr.item || cr.item.type !== "image"
                name: "description"
                size: Theme.dp(20)
                color: cr.pinned ? Theme.fgAccentContainer : Theme.subtext
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
                color: Theme.error
                opacity: delArea.pressed ? Theme.statePressed : (delArea.containsMouse ? Theme.stateHover : 0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(100)
                        easing.type: Theme.easeStandard
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "delete"
                size: Math.round(Theme.dp(32) * 0.55)
                color: Theme.error
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
