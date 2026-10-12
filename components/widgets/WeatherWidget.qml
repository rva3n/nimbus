import QtQuick
import "../../core"
import "../../ui"

// Погода на рабочем столе: глиф-погода, температура, место/описание.
// Данные — core/Weather (сам обновляется по Prefs.weatherAuto).
Rectangle {
    id: w

    color: Theme.withBlur(Theme.mHigh)
    radius: Theme.shapeLgInc
    clip: true
    implicitWidth: Theme.dp(236)
    implicitHeight: body.implicitHeight + Theme.dp(32)

    // оголовок загрузки: тихий пульс, пока нет данных
    readonly property bool pulsing: Weather.loading && !Weather.hasData

    Row {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.dp(16)
        spacing: Theme.dp(12)

        Item {
            id: iconCloud

            implicitWidth: Theme.dp(44)
            implicitHeight: Theme.dp(44)

            Icon {
                anchors.fill: parent
                name: Weather.icon
                size: Theme.dp(40)
                color: Weather.hasData ? Theme.accent : Theme.subtext
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.a(Theme.secondaryContainer, 0.6)
                visible: w.pulsing

                SequentialAnimation on opacity {
                    running: w.pulsing
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 0.55
                        to: 0.95
                        duration: Theme.ms(700)
                    }

                    NumberAnimation {
                        from: 0.95
                        to: 0.55
                        duration: Theme.ms(700)
                    }

                }

            }

        }

        Column {
            // колонка не шире остатка строки, иначе описание вытесняет правую кромку
            width: body.width - (iconCloud.implicitWidth) - body.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            Row {
                spacing: Theme.dp(10)
                width: parent.width

                LText {
                    size: Theme.dp(34)
                    weight: 560
                    tabular: true
                    color: Theme.text
                    text: Weather.hasData ? Math.round(Weather.temp) + "°" : "—°"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    LText {
                        width: Theme.dp(106)
                        role: "titleSmall"
                        color: Theme.text
                        elide: Text.ElideRight
                        text: Weather.place !== "" ? Weather.place : (Weather.hasData ? Weather.desc : "Погода")
                    }

                    LText {
                        width: Theme.dp(106)
                        // роль «подпись»: слишком длинное описание съедает ширину карточки
                        visible: text !== ""
                        color: Theme.subtext
                        elide: Text.ElideRight
                        font.pixelSize: Theme.dp(12)
                        font.family: Theme.fontFamily
                        text: Weather.error !== "" ? "не удалось получить погоду" : (Weather.hasData ? Weather.desc : "загрузка…")
                    }

                }

            }

        }

    }

}
