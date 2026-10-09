import QtQuick
import "../core"

// M3 filled-поле: фон bgTile, радиус 12, высота 40. При фокусе — акцентная
// рамка. forceActiveFocus() наследуется от FocusScope и передаёт фокус
// внутреннему TextInput (focus: true), так что клавиатура работает сразу.
FocusScope {
    id: tf

    property alias text: input.text
    property string placeholder: ""
    property int echoMode: TextInput.Normal
    readonly property bool active: input.activeFocus

    signal accepted()

    implicitWidth: Theme.dp(240)
    implicitHeight: Theme.dp(40)
    opacity: tf.enabled ? 1 : Theme.disabledContent

    Rectangle { // корпус
        id: box
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Theme.bgTile
        border.width: tf.active ? Theme.dp(2) : 0
        border.color: Theme.accent

        Behavior on border.width {
            NumberAnimation {
                duration: Theme.ms(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveEffects
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.dp(12)
        anchors.rightMargin: Theme.dp(12)
        focus: true
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.fgOnFill
        echoMode: tf.echoMode
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("bodyMedium")
        font.weight: Theme.typeWeight("bodyMedium")
        cursorDelegate: Rectangle {
            width: Theme.dp(2)
            color: Theme.accent
        }
        onAccepted: tf.accepted()

        Text { // плейсхолдер
            anchors.fill: parent
            visible: input.text === ""
            text: tf.placeholder
            color: Theme.alpha(Theme.subtext, 0.6)
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
