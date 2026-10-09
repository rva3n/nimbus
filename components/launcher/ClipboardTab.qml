pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Вкладка «Буфер»: закреплённые сверху, затем история cliphist. Клик/Enter —
// копирование, pin/delete — как в ClipRow. Индексы: сначала pins, затем items.
ColumnLayout {
    id: tab

    property string query: ""
    property int sel: 0
    property var shell: null
    property bool active: false

    signal hovered(int index)

    // фильтр по тексту/превью, регистронезависимо
    function matches(it) {
        const q = tab.query.trim().toLowerCase();
        if (q === "") return true;
        const src = (it.text !== undefined && it.text !== "") ? it.text : (it.preview || "");
        return String(src).toLowerCase().indexOf(q) !== -1;
    }
    readonly property var fPins: Clip.pins.filter(tab.matches)
    readonly property var fItems: Clip.items.filter(tab.matches)
    readonly property int count: tab.fPins.length + tab.fItems.length

    spacing: Theme.dp(4)

    onActiveChanged: if (tab.active) Clip.refresh()
    onSelChanged: {
        if (tab.sel >= tab.fPins.length && tab.sel < tab.count)
            itemsView.positionViewAtIndex(tab.sel - tab.fPins.length, ListView.Contain);
    }

    function activate(index) {
        if (index < tab.fPins.length) {
            const p = tab.fPins[index];
            if (p) Clip.copyPin(p);
        } else {
            const it = tab.fItems[index - tab.fPins.length];
            if (it) Clip.copy(it.id, it.type);
        }
        if (tab.shell) tab.shell.closeOverlays();
    }

    // ── Закреплённые ──────────────────────────────────────────────────
    Text {
        visible: tab.fPins.length > 0
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.dp(2)
        text: "Закреплённые"
        color: Theme.subtext
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelLarge")
        font.weight: Theme.typeWeight("labelLarge")
    }

    ColumnLayout {
        visible: tab.fPins.length > 0
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: tab.fPins

            delegate: ClipItem {
                baseIndex: 0
                pinned: true
                selected: tab.sel === rowIndex
                onHovered: (i) => tab.hovered(i)
                onActivated: (i) => tab.activate(i)
            }
        }
    }

    // ── История ───────────────────────────────────────────────────────
    ListView {
        id: itemsView

        visible: tab.fItems.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Theme.dp(96), Math.min(Theme.dp(340), contentHeight))
        model: tab.fItems
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds

        delegate: ClipItem {
            baseIndex: tab.fPins.length
            selected: tab.sel === rowIndex
            onHovered: (i) => tab.hovered(i)
            onActivated: (i) => tab.activate(i)
        }
    }

    Item { // пусто / нет результатов / загрузка
        visible: tab.count === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.dp(220)

        Text {
            anchors.centerIn: parent
            text: tab.query.trim() !== "" ? "Ничего не найдено"
                : (Clip.loading ? "загрузка…" : "Буфер пуст")
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }
    }

    Item { // опасная строка: очистить всю историю
        visible: Clip.items.length > 0
        Layout.fillWidth: true
        implicitHeight: Theme.dp(48)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLg
            color: wipeArea.pressed ? Theme.bgActive : (wipeArea.containsMouse ? Theme.bgHover : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.durDefaultEffects }
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
            cursorShape: Qt.PointingHandCursor
            onClicked: Clip.wipe()
        }
    }

    // ── строка буфера: превью/иконка, текст в 2 строки, pin и delete ──
    component ClipItem: ColumnLayout {
        id: ci

        required property var modelData
        required property int index

        property int baseIndex: 0
        property bool pinned: false
        property bool selected: false

        signal hovered(int rowIndex)
        signal activated(int rowIndex)

        readonly property int rowIndex: ci.baseIndex + ci.index

        Layout.fillWidth: true
        spacing: 0

        Divider {
            visible: ci.rowIndex > 0
            Layout.fillWidth: true
            leftInset: Theme.dp(56)
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(Theme.dp(56), rowLayout.implicitHeight + Theme.dp(20))

            Rectangle {
                id: bg
                anchors.fill: parent
                radius: Theme.radiusMd
                color: (ci.selected || ci.pinned) ? Theme.accentContainer
                     : (clipArea.pressed ? Theme.bgActive : (clipArea.containsMouse ? Theme.bgHover : "transparent"))
                border.width: ci.selected ? 1 : 0
                border.color: Theme.accentBorder

                Behavior on color {
                    ColorAnimation { duration: Theme.durDefaultEffects }
                }
            }

            MouseArea {
                id: clipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: ci.hovered(ci.rowIndex)
                onClicked: ci.activated(ci.rowIndex)
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: Theme.dp(10)
                spacing: Theme.dp(10)

                Item { // превью-картинка 44×32 либо контейнер иконки 40×40
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Theme.dp(44)
                    implicitHeight: Theme.dp(40)

                    Rectangle {
                        anchors.centerIn: parent
                        visible: ci.modelData && ci.modelData.type === "image"
                        implicitWidth: Theme.dp(44)
                        implicitHeight: Theme.dp(32)
                        radius: Theme.radiusMd
                        color: Theme.bgTrack
                        clip: true

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            // items кладут thumb, pins — file
                            source: visible ? ("file://" + (ci.modelData.thumb || ci.modelData.file || "")) : ""
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: !(ci.modelData && ci.modelData.type === "image")
                        implicitWidth: Theme.dp(40)
                        implicitHeight: Theme.dp(40)
                        radius: Theme.radiusPill
                        color: ci.pinned ? Theme.accentContainer : Theme.bgTrack

                        Icon {
                            anchors.centerIn: parent
                            name: "description"
                            size: Theme.dp(20)
                            color: ci.pinned ? Theme.fgAccentContainer : Theme.subtext
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: (ci.selected || ci.pinned) ? Theme.fgAccentContainer : Theme.text
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
                    text: ci.modelData ? (ci.modelData.type === "image" ? "Изображение"
                          : (ci.modelData.text !== undefined && ci.modelData.text !== "" ? ci.modelData.text : ci.modelData.preview)) : ""
                }

                IconButton { // pin: закреплённая строка — filled
                    Layout.alignment: Qt.AlignVCenter
                    icon: "push_pin"
                    size: "s"
                    variant: ci.pinned ? "filled" : "standard"
                    onClicked: ci.pinned ? Clip.unpin(ci.modelData.id) : Clip.pin(ci.modelData.id)
                }

                Item { // delete в error-тоне (у ui/IconButton нет error-варианта)
                    Layout.alignment: Qt.AlignVCenter
                    visible: !ci.pinned
                    implicitWidth: Theme.dp(32)
                    implicitHeight: Theme.dp(32)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusPill
                        color: delArea.containsMouse || delArea.pressed ? Theme.errorContainer : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.durDefaultEffects }
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "delete"
                        size: Theme.dp(18)
                        color: delArea.containsMouse ? Theme.fgErrorContainer : Theme.error

                        Behavior on color {
                            ColorAnimation { duration: Theme.durDefaultEffects }
                        }
                    }

                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Clip.del(ci.modelData.id)
                    }
                }
            }
        }
    }
}
