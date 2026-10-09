import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Страница «Погода»: текущие условия, прогноз по часам и на 5 дней.
// Данные — из core/Weather.qml (Open-Meteo).
ColumnLayout {
    id: page

    property var win: null

    Layout.fillWidth: true
    spacing: Theme.dp(10)
    visible: win !== null && win.mode === "panel" && win.page === "" && win.shell && win.shell.panelTab === "weather"

    // ── загрузка и ошибка ─────────────────────────────────────────────
    Text {
        visible: Weather.loading && !Weather.hasData
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "загрузка…"
        color: Theme.subtext
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("bodySmall")
        font.weight: Theme.typeWeight("bodySmall")
    }

    Rectangle {
        visible: Weather.error !== ""
        Layout.fillWidth: true
        implicitHeight: errRow.implicitHeight + Theme.dp(20)
        radius: Theme.radiusXl
        color: Theme.errorContainer

        RowLayout {
            id: errRow

            anchors.fill: parent
            anchors.margins: Theme.dp(10)
            spacing: Theme.dp(10)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: "error"
                size: Theme.dp(20)
                color: Theme.fgErrorContainer
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: Weather.error
                color: Theme.fgErrorContainer
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }

            Button {
                Layout.alignment: Qt.AlignVCenter
                text: "Повторить"
                variant: "tonal"
                onClicked: Weather.refresh()
            }
        }
    }

    // ── Сейчас ────────────────────────────────────────────────────────
    Card {
        visible: Weather.hasData
        Layout.fillWidth: true
        title: "Сейчас"
        actionIcon: "refresh"
        onActionClicked: Weather.refresh()

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(16)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: Weather.icon
                size: Theme.dp(48)
                color: Theme.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    text: Math.round(Weather.temp) + "°"
                    color: Theme.text
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("displayMedium")
                    font.weight: Theme.typeWeight("displayMedium")
                }

                Text {
                    Layout.fillWidth: true
                    text: Weather.desc
                    color: Theme.subtext
                    elide: Text.ElideRight
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }

        RowLayout { // детали: ощущается, влажность, ветер, место
            Layout.fillWidth: true
            Layout.topMargin: Theme.dp(8)
            spacing: Theme.dp(14)

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "Ощущается " + Math.round(Weather.feels) + "°"
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.dp(4)

                Icon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "water_drop"
                    size: Theme.dp(16)
                    color: Theme.subtext
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Math.round(Weather.humidity) + "%"
                    color: Theme.subtext
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.dp(4)

                Icon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "air"
                    size: Theme.dp(16)
                    color: Theme.subtext
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Math.round(Weather.wind) + " м/с"
                    color: Theme.subtext
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.dp(4)

                Icon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "public"
                    size: Theme.dp(16)
                    color: Theme.subtext
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: Weather.place
                    color: Theme.subtext
                    elide: Text.ElideRight
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                }
            }
        }
    }

    // ── По часам ──────────────────────────────────────────────────────
    Card {
        visible: Weather.hasData && Weather.hourly.length > 0
        Layout.fillWidth: true
        title: "По часам"

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(2)

            Repeater {
                model: Weather.hourly.slice(0, 8)

                delegate: ColumnLayout {
                    required property var modelData
                    // день/ночь по метке часа — для иконок прогноза
                    readonly property bool dayHour: {
                        const h = parseInt(modelData.label, 10);
                        return isNaN(h) ? Weather.isDay : (h >= 7 && h < 21);
                    }
                    Layout.fillWidth: true
                    spacing: Theme.dp(4)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.label
                        color: Theme.subtext
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("labelSmall")
                        font.weight: Theme.typeWeight("labelSmall")
                    }

                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        name: Weather.wmoIcon(modelData.code, dayHour)
                        size: Theme.dp(18)
                        color: Theme.subtext
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.temp + "°"
                        color: Theme.text
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall")
                    }
                }
            }
        }
    }

    // ── На 5 дней ─────────────────────────────────────────────────────
    Card {
        visible: Weather.hasData && Weather.daily.length > 0
        Layout.fillWidth: true
        title: "На 5 дней"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: Weather.daily.slice(0, 5)

                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0

                    Divider {
                        visible: index > 0
                        Layout.fillWidth: true
                        leftInset: Theme.dp(16)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.dp(6)
                        Layout.bottomMargin: Theme.dp(6)
                        Layout.leftMargin: Theme.dp(8)
                        Layout.rightMargin: Theme.dp(8)
                        spacing: Theme.dp(10)

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.day
                            color: Theme.text
                            elide: Text.ElideRight
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyLarge")
                            font.weight: Theme.typeWeight("bodyLarge")
                        }

                        Icon {
                            Layout.alignment: Qt.AlignVCenter
                            name: Weather.wmoIcon(modelData.code, true)
                            size: Theme.dp(18)
                            color: Theme.subtext
                        }

                        Text {
                            Layout.preferredWidth: Theme.dp(34)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(modelData.min) + "°"
                            color: Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }

                        Text {
                            Layout.preferredWidth: Theme.dp(34)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(modelData.max) + "°"
                            color: Theme.text
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodySmall")
                            font.weight: Theme.typeWeight("bodySmall")
                        }
                    }
                }
            }
        }
    }
}
