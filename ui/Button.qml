import QtQuick
import QtQuick.Layouts
import "../core"

// M3 Expressive-кнопка Nimbus: пилюля, при нажатии сжимается, выбранная
// (checkable) становится скруглённым квадратом.
// variant: filled | tonal | outlined | text; size: s=32 | m=40.
Item {
    id: btn

    property string text: ""
    property string icon: ""
    property string variant: "filled"
    property string size: "s"
    property bool disabled: false
    property bool checkable: false
    property bool checked: false

    signal clicked()
    signal toggled(bool value)

    readonly property bool _selected: btn.checkable && btn.checked
    readonly property bool _hasIcon: btn.icon !== ""
    readonly property bool _hasText: btn.text !== ""
    readonly property int _h: btn.size === "m" ? Theme.dp(40) : Theme.dp(32)
    readonly property int _padH: btn.size === "m" ? Theme.dp(24) : Theme.dp(16)
    readonly property int _iconPx: btn.size === "m" ? Theme.dp(20) : Theme.dp(18)

    // форма: покой — пилюля, нажатие — плотнее, выбор — квадратнее
    readonly property real _restRadius: btn._selected ? (btn.size === "m" ? Theme.shapeLg : Theme.shapeMd) : Theme.radiusPill
    readonly property real _pressRadius: btn.size === "m" ? Theme.shapeMd : Theme.shapeSm

    readonly property color _container: {
        if (btn.disabled)
            return (btn.variant === "outlined" || btn.variant === "text") ? "transparent" : Theme.a(Theme.text, Theme.disabledContainer);

        if (btn.checkable) {
            if (btn._selected) {
                switch (btn.variant) {
                case "filled": return Theme.accent;
                case "tonal": return Theme.accent;
                case "text": return Theme.accentContainer;
                default: return Theme.inverseSurface; // outlined
                }
            }
            switch (btn.variant) {
            case "filled": return Theme.bgTrack;
            case "tonal": return Theme.accentContainer;
            default: return "transparent"; // outlined / text
            }
        }

        switch (btn.variant) {
        case "filled": return Theme.accent;
        case "tonal": return Theme.accentContainer;
        default: return "transparent"; // outlined / text
        }
    }

    readonly property color _content: {
        if (btn.disabled)
            return btn.variant === "outlined" ? Theme.subtextDim : Theme.a(Theme.text, Theme.disabledContent);

        if (btn.checkable) {
            if (btn._selected) {
                switch (btn.variant) {
                case "outlined": return Theme.fgInverseSurface;
                case "text": return Theme.fgAccentContainer;
                default: return Theme.fgOnFill; // filled / tonal
                }
            }
            switch (btn.variant) {
            case "filled": return Theme.subtext;
            case "tonal": return Theme.fgAccentContainer;
            case "outlined": return Theme.text;
            default: return Theme.accent; // text
            }
        }

        switch (btn.variant) {
        case "filled": return Theme.fgOnFill;
        case "tonal": return Theme.fgAccentContainer;
        case "outlined": return Theme.text;
        default: return Theme.accent; // text
        }
    }

    readonly property color _border: {
        if (btn.variant !== "outlined")
            return "transparent";
        if (btn.disabled)
            return Theme.a(Theme.text, Theme.disabledContainer);
        if (btn.checkable && btn._selected)
            return "transparent";
        return Theme.outline;
    }

    implicitWidth: row.implicitWidth + btn._padH * 2
    implicitHeight: btn._h
    scale: (area.pressed && !btn.disabled) ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durQuick
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveEffects
        }

    }

    Rectangle {
        id: box

        anchors.fill: parent
        radius: area.pressed ? btn._pressRadius : btn._restRadius
        color: btn._container
        border.width: btn.variant === "outlined" ? 1 : 0
        border.color: btn._border

        // state layer (ховер/нажатие) поверх контейнера, под содержимым
        Rectangle {
            anchors.fill: parent
            radius: box.radius
            color: btn._content
            opacity: btn.disabled ? 0 : (area.pressed ? Theme.statePressed : (area.containsMouse ? Theme.stateHover : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(100)
                    easing.type: Theme.easeStandard
                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Theme.dp(8)

        Icon {
            visible: btn._hasIcon
            Layout.alignment: Qt.AlignVCenter
            name: btn.icon
            size: btn._iconPx
            color: btn._content
        }

        Text {
            visible: btn._hasText
            Layout.alignment: Qt.AlignVCenter
            text: btn.text
            color: btn._content
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelLarge")
            font.weight: Theme.typeWeight("labelLarge")
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: !btn.disabled
        cursorShape: Qt.PointingCursor

        onClicked: {
            if (btn.checkable) {
                btn.checked = !btn.checked;
                btn.toggled(btn.checked);
            }
            btn.clicked();
        }
    }

}
