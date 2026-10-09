import QtQuick
import "../core"

// Маленький лейбл-пилюля Nimbus.
// tone: accent | error | neutral.
Rectangle {
    id: badge

    property string text: ""
    property string tone: "accent"

    readonly property color _fg: {
        if (badge.tone === "error")
            return Theme.fgErrorContainer;
        if (badge.tone === "neutral")
            return Theme.subtext;
        return Theme.fgOnFill;
    }

    implicitWidth: label.implicitWidth + Theme.dp(8) * 2
    implicitHeight: Theme.dp(20)
    radius: Theme.radiusPill
    color: badge.tone === "error" ? Theme.errorContainer : (badge.tone === "neutral" ? Theme.bgTrack : Theme.accent)

    Text {
        id: label

        anchors.centerIn: parent
        text: badge.text
        color: badge._fg
        font.family: Theme.textFont
        font.pixelSize: Theme.fs(10)
        font.weight: Theme.typeWeight("labelSmall")
    }

}
