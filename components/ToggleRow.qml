import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Lucid-строка настройки (анатомия SettingRow/ListItem): высота 56–64dp,
// ведущий слот-иконка 40dp, заголовок LText bodyLarge + supporting bodySmall,
// справа Switch. Фон прозрачный — строка живёт внутри ui/Card; ховер и
// нажатие рисует StateLayer.
//
// Контракт: checked — источник правды, Switch к нему привязан.
// signal toggled(bool value) сообщает новое значение наружу
// (onToggled: (v) => ...). После переключения привязка Switch
// переустанавливается, поэтому внешние изменения checked (опрос
// nmcli/bluetoothctl, Prefs) продолжают отражаться на переключателе —
// клик по Switch не «отвязывает» его.
Rectangle {
    id: tr

    property string label: ""
    property string sub: ""
    property string icon: ""
    property bool checked: false
    // обратная совместимость: прежние вызовы писали active: ...
    property alias active: tr.checked

    signal toggled(bool value)

    function _emit(v) {
        tr.toggled(v);
        // Switch сам инвертирует checked и убивает декларативную привязку —
        // возвращаем её, чтобы строка оставалась управляемой извне
        sw.checked = Qt.binding(function () { return tr.checked; });
    }

    implicitHeight: Math.max(Theme.dp(tr.sub !== "" ? 64 : 56), row.implicitHeight + Theme.dp(16))
    // строка всегда тянется на всю ширину карточки: в ColumnLayout у Rectangle
    // без этого нулевая ширина, и Switch наезжает на подписи
    Layout.fillWidth: true
    radius: Theme.rad(16)
    color: "transparent"

    StateLayer {
        anchors.fill: parent
        radius: tr.radius
        tint: tr.checked ? Theme.primary : Theme.text
        onClicked: tr._emit(!tr.checked)
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Theme.dp(12)
        anchors.rightMargin: Theme.dp(12)
        spacing: Theme.dp(12)

        Rectangle { // ведущая иконка 40×40
            visible: tr.icon !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.dp(40)
            implicitHeight: Theme.dp(40)
            radius: Theme.rad(12)
            color: tr.checked ? Theme.accentContainer : Theme.bgTrack

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durDefaultEffects
                }
            }

            Icon {
                anchors.centerIn: parent
                name: tr.icon
                size: Theme.dp(22)
                fill: tr.checked ? 1 : 0
                color: tr.checked ? Theme.fgAccentContainer : Theme.subtext

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durDefaultEffects
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.dp(2)

            LText {
                Layout.fillWidth: true
                role: "bodyLarge"
                weight: 480
                color: Theme.text
                elide: Text.ElideRight
                text: tr.label
            }

            LText {
                Layout.fillWidth: true
                visible: tr.sub !== ""
                role: "bodySmall"
                color: Theme.subtext
                elide: Text.ElideRight
                text: tr.sub
            }
        }

        Switch {
            id: sw

            Layout.alignment: Qt.AlignVCenter
            checked: tr.checked
            onToggled: tr._emit(sw.checked)
        }
    }
}
