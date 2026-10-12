import QtQuick
import Qt5Compat.GraphicalEffects
import "../core"

// Картинка, вырезанная одной из m3 expressive-фигур (порт lucidui/ShapedImage.qml).
// Дети рисуются на её месте, пока картинка не готова, на заливке самой фигуры.
Item {
    id: si

    property alias source: img.source
    property string shape: "cookie12"
    property real spin: 0
    property color fallbackColor: Theme.primaryContainer
    property int decode: 256
    readonly property bool ready: img.status === Image.Ready
    default property alias fallback: fb.data

    MaterialShape {
        anchors.fill: parent
        shape: si.shape
        spin: si.spin
        color: si.fallbackColor
        visible: !si.ready
    }

    Item {
        id: fb

        anchors.fill: parent
        visible: !si.ready
    }

    Image {
        id: img

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: si.decode
        sourceSize.height: si.decode
        asynchronous: true
        cache: false
        visible: false
    }

    MaterialShape {
        id: mask

        anchors.fill: parent
        shape: si.shape
        spin: si.spin
        color: "black"
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        visible: si.ready
        source: img
        maskSource: mask
    }

}
