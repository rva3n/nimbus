import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Система на рабочем столе: волнистое кольцо CPU + линейный прогресс памяти,
// скорость и температура, если она обнаружена (core/SysStats).
Rectangle {
    id: w

    color: Theme.withBlur(Theme.mHigh)
    radius: Theme.shapeLgInc
    clip: true
    implicitWidth: Theme.dp(236)
    implicitHeight: metrics.implicitHeight + Theme.dp(32)

    function gb(v) { return (v / 1073741824).toFixed(1).replace(".", ","); }

    RowLayout {
        id: metrics

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.dp(16)
        spacing: Theme.dp(16)

        // волнистое кольцо CPU (ui/CircularProgress): % в центре
        CircularProgress {
            Layout.preferredWidth: Theme.dp(68)
            Layout.preferredHeight: Theme.dp(68)
            Layout.alignment: Qt.AlignVCenter
            value: SysStats.cpu
            thickness: Theme.dp(5)
            animated: w.visible

            content: Column {
                anchors.centerIn: parent
                spacing: 0

                LText {
                    width: Theme.dp(48)
                    size: Theme.dp(15)
                    weight: 560
                    tabular: true
                    color: Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(SysStats.cpu * 100) + "%"
                }

                LText {
                    width: Theme.dp(48)
                    role: "labelSmall"
                    color: Theme.subtext
                    horizontalAlignment: Text.AlignHCenter
                    text: "CPU"
                }

            }

        }

        ColumnLayout {
            id: info

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.dp(6)

            LinearProgress {
                Layout.fillWidth: true
                value: SysStats.memFrac
                thickness: Theme.dp(5)
                animated: w.visible
            }

            LText {
                role: "bodySmall"
                color: Theme.subtext
                text: "Память " + w.gb(SysStats.memUsed) + " / " + w.gb(SysStats.memTotal) + " ГБ"
            }

            // скорость хоста и температура, когда сенсор нашёлся
            Row {
                spacing: Theme.dp(6)
                visible: SysStats.tempC > 0

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "thermostat"
                    size: Theme.dp(15)
                    color: Theme.subtext
                }

                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodySmall"
                    color: Theme.subtext
                    tabular: true
                    text: Math.round(SysStats.tempC) + "°"
                }

            }

        }

    }

}
