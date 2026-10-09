import QtQuick
import "../core"

// Точки воркспейсов Umbriel: активный — широкая пилюля, остальные — точки.
// Модель — по индексу (длина списка), а не сам массив: делегаты не пересоздаются
// на каждое событие, поэтому анимации ширины/цвета реально играют.
Row {
    id: wsRow
    property string output: ""
    spacing: Theme.dp(5)

    readonly property var items: Umbriel.workspacesFor(output)

    Repeater {
        model: wsRow.items.length

        delegate: Item {
            id: dotHolder
            required property int index

            readonly property var wsData: wsRow.items[index] || null
            readonly property bool active: wsData ? wsData.active : false
            readonly property bool occupied: wsData ? wsData.occupied : false

            readonly property color dotColor: active ? Theme.accent
                 : occupied ? Theme.subtext
                 : Theme.subtextDim

            // фикс. высота контейнера: ширина пилюли анимируется, строка не «прыгает»
            width: active ? Theme.dp(16) : Theme.dp(6)
            height: Theme.dp(6)

            Behavior on width {
                NumberAnimation {
                    duration: Theme.ms(160)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveEffects
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: Theme.radiusPill
                color: dotHolder.dotColor

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.ms(160)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveEffects
                    }
                }
            }
        }
    }
}
