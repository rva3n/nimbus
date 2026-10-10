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

    // влажность/ветер могут отсутствовать (тогда приходит NaN) — чип пропускаем
    readonly property bool hasHumidity: !isNaN(Weather.humidity)
    readonly property bool hasWind: !isNaN(Weather.wind)

    // чип-выделение: пилюля h26, внутри иконка 13 + подпись labelMedium
    component StatChip: Rectangle {
        id: chip

        property string icon: ""
        property string label: ""

        implicitHeight: Theme.dp(26)
        implicitWidth: chipRow.implicitWidth + Theme.dp(20)
        radius: Theme.radiusPill
        color: Theme.bgTrack

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: Theme.dp(4)

            Icon {
                Layout.alignment: Qt.AlignVCenter
                name: chip.icon
                size: Theme.dp(13)
                color: Theme.subtext
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: chip.label
                color: Theme.subtext
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("labelMedium")
                font.weight: Theme.typeWeight("labelMedium")
            }
        }
    }

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

        ColumnLayout { // герой и ряд чипов: ровный ритм 12 между блоками
            Layout.fillWidth: true
            spacing: Theme.dp(12)

            RowLayout { // герой: блок иконки + температура/описание/место
                Layout.fillWidth: true
                spacing: Theme.dp(12)

                Rectangle { // контейнер иконки 64×64
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Theme.dp(64)
                    implicitHeight: Theme.dp(64)
                    radius: Theme.radiusLg
                    color: Theme.accentContainer

                    Icon {
                        anchors.centerIn: parent
                        name: Weather.icon
                        size: Theme.dp(32)
                        color: Theme.fgAccentContainer
                    }
                }

                ColumnLayout { // температура, описание, место
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.dp(2)

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
                        font.pixelSize: Theme.typeSize("bodyLarge")
                        font.weight: Theme.typeWeight("bodyLarge")
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Weather.place
                        color: Theme.subtextDim
                        elide: Text.ElideRight
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("labelMedium")
                        font.weight: Theme.typeWeight("labelMedium")
                    }
                }
            }

            RowLayout { // чипы-выделения: по содержимому, слева, без растяжки
                Layout.fillWidth: true
                spacing: Theme.dp(6)

                StatChip {
                    icon: "device_thermostat"
                    label: "Ощущается " + Math.round(Weather.feels) + "°"
                }

                StatChip {
                    visible: page.hasHumidity
                    icon: "water_drop"
                    label: Math.round(Weather.humidity) + "%"
                }

                StatChip {
                    visible: page.hasWind
                    icon: "air"
                    label: Math.round(Weather.wind) + " м/с"
                }

                Item { Layout.fillWidth: true } // остаток ширины — справа от чипов
            }
        }
    }

    // ── По часам ──────────────────────────────────────────────────────
    Card {
        visible: Weather.hasData && Weather.hourly.length > 0
        Layout.fillWidth: true
        title: "По часам"

        RowLayout { // до 6 мини-карточек 52×76: 6×52 + 5×6 = 342 < 344 — без обрезки
            Layout.fillWidth: true
            spacing: Theme.dp(6)

            Repeater {
                model: Weather.hourly.slice(0, 6)

                delegate: Rectangle { // час — отдельная мини-карточка
                    id: hourCell

                    required property var modelData
                    // день/ночь по метке часа — для иконок прогноза
                    readonly property bool dayHour: {
                        const h = parseInt(modelData.label, 10);
                        return isNaN(h) ? Weather.isDay : (h >= 7 && h < 21);
                    }

                    Layout.preferredWidth: Theme.dp(52)
                    Layout.preferredHeight: Theme.dp(76)
                    radius: Theme.radiusMd
                    color: Theme.bgTile

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.dp(6)
                        spacing: Theme.dp(4)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: hourCell.modelData.label
                            color: Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("labelSmall")
                            font.weight: Theme.typeWeight("labelSmall")
                        }

                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            name: Weather.wmoIcon(hourCell.modelData.code, hourCell.dayHour)
                            size: Theme.dp(16)
                            color: Theme.subtext
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: hourCell.modelData.temp + "°"
                            color: Theme.text
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyMedium")
                            font.weight: Theme.typeWeight("bodyMedium")
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true } // ряд прижат влево, ячейки не растягиваются
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
                        leftInset: Theme.dp(36)
                    }

                    RowLayout { // строка дня: колонки фиксированной ширины, без прижатий
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.dp(40)
                        Layout.leftMargin: Theme.dp(8)
                        Layout.rightMargin: Theme.dp(8)
                        spacing: Theme.dp(12)

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

                        Text { // минимум — колонка, выравнивание вправо
                            Layout.preferredWidth: Theme.dp(34)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(modelData.min) + "°"
                            color: Theme.subtext
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyMedium")
                            font.weight: Theme.typeWeight("bodyMedium")
                        }

                        Text { // максимум — фикс. ширина 40, вправо (от min отделён spacing 12)
                            Layout.preferredWidth: Theme.dp(40)
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(modelData.max) + "°"
                            color: Theme.text
                            font.family: Theme.textFont
                            font.pixelSize: Theme.typeSize("bodyMedium")
                            font.weight: Theme.typeWeight("bodyMedium")
                        }
                    }
                }
            }
        }
    }
}
