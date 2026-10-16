import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// M3 Expressive-плитка быстрого доступа (анатомия Lucid SmallTile):
// скруглённый контейнер rad(12) с поверхностью surfaceHighest,
// иконка dp(24) и подпись labelLarge. ON — accentContainer, OFF — нейтральная
// поверхность; ховер/нажатие/рябь — StateLayer; нажатие слегка морфит плитку.
// tileCols/tileW/tileH повторяют раскладку Lucid: tileW из ширины контента,
// tileH = tileW + dp(20) — вызывающий кладёт плитки в Grid с этим шагом.
Item {
    id: tile

    property string icon: ""
    property string label: ""
    property bool active: false

    signal tapped()

    // раскладка Lucid: 6 колонок, шаг по X = tileW + sp2, по Y = tileH + sp3
    property int tileCols: 6
    property real contentWidth: parent ? parent.width : Theme.dp(300)
    readonly property real tileGap: Theme.dp(8)
    readonly property real tileW: (tile.contentWidth - tile.tileGap * (tile.tileCols - 1)) / tile.tileCols
    readonly property real tileH: tile.tileW + Theme.dp(20)

    Layout.fillWidth: true
    implicitWidth: tile.tileW
    implicitHeight: Theme.dp(72)
    scale: area.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durFastSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveFastSpatial
        }
    }

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: Theme.rad(12)
        color: tile.active ? Theme.accentContainer : Theme.mHighest

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }
        }
    }

    StateLayer {
        id: area

        radius: bg.radius
        tint: tile.active ? Theme.fgAccentContainer : Theme.text
        onClicked: tile.tapped()
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.dp(4)

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tile.icon
            size: Theme.dp(24)
            fill: tile.active ? 1 : 0
            color: tile.active ? Theme.fgAccentContainer : Theme.subtext

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }
        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "labelLarge"
            color: tile.active ? Theme.fgAccentContainer : Theme.text
            text: tile.label

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }
        }
    }
}
