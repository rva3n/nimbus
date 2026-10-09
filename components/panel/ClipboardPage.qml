import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui"

// Буфер обмена: закреплённые и история — сгруппированы в Card,
// строки прозрачные с разделителями, очистка — danger-строка.
ColumnLayout {
    id: clipboardPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "clipboard"
    Layout.fillWidth: true
    spacing: Theme.dp(10)

    // ── Закреплённые ──────────────────────────────────────────────────
    Card {
        visible: Clip.pins.length > 0
        Layout.fillWidth: true
        title: "Закреплённые"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: Clip.pins

                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0

                    Divider {
                        visible: index > 0
                        Layout.fillWidth: true
                        leftInset: Theme.dp(56)
                    }

                    ClipRow {
                        Layout.fillWidth: true
                        item: modelData
                        pinned: true
                    }
                }
            }
        }
    }

    // ── История ───────────────────────────────────────────────────────
    Card {
        Layout.fillWidth: true
        title: "История"
        actionIcon: "refresh"
        onActionClicked: Clip.refresh()

        Text {
            visible: Clip.loading
            Layout.fillWidth: true
            text: "загрузка…"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodySmall")
            font.weight: Theme.typeWeight("bodySmall")
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 320
            model: Clip.items
            clip: true
            spacing: 0

            delegate: ColumnLayout {
                required property var modelData
                required property int index
                width: ListView.view.width
                spacing: 0

                Divider {
                    visible: index > 0
                    Layout.fillWidth: true
                    leftInset: Theme.dp(56)
                }

                ClipRow {
                    Layout.fillWidth: true
                    item: modelData
                }
            }
        }

        Item { // опасная строка: очистить всю историю
            Layout.fillWidth: true
            implicitHeight: Theme.dp(48)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLg
                color: wipeArea.pressed ? Theme.bgActive : (wipeArea.containsMouse ? Theme.bgHover : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(8)
                anchors.rightMargin: Theme.dp(16)
                spacing: Theme.dp(12)

                Rectangle { // контейнер иконки в error-тоне
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Theme.dp(40)
                    implicitHeight: Theme.dp(40)
                    radius: Theme.radiusPill
                    color: Theme.errorContainer

                    Icon {
                        anchors.centerIn: parent
                        name: "delete_sweep"
                        size: Theme.dp(20)
                        color: Theme.fgErrorContainer
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: "Очистить историю"
                    color: Theme.text
                    elide: Text.ElideRight
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodyLarge")
                    font.weight: Theme.typeWeight("bodyLarge")
                }
            }

            MouseArea {
                id: wipeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingCursor
                onClicked: Clip.wipe()
            }
        }
    }
}
