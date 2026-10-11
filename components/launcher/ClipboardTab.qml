pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Вкладка «Буфер»: закреплённые сверху, затем история cliphist. Клик/Enter —
// копирование и (если есть wtype) вставка Ctrl+V в вернувшее фокус окно,
// pin/delete — как в ClipRow. Индексы: сначала pins, затем items.
// Единый ритм строк (как в AppsTab): строка 48, превью 44×32, divider с
// отступом от превью (52), кнопки справа у края (margin 4, spacing 4).
ColumnLayout {
    id: tab

    property string query: ""
    property int sel: 0
    property var shell: null
    property bool active: false
    // есть ли wtype в PATH — как в EmojiTab; без него просто копируем
    property bool haveWtype: false

    signal hovered(int index)

    // экранирование одинарных кавычек для sh
    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

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

    // вставка в приложение, которое вернёт фокус после закрытия оверлея:
    // Ctrl+V через wtype (как EmojiTab). Без wtype ничего не делаем — текст
    // уже в буфере, падения нет.
    function pasteInto() {
        if (!tab.haveWtype) return;
        Quickshell.execDetached(["sh", "-c", "setsid -f sh -c 'sleep 0.25; wtype -M ctrl v -m ctrl'"]);
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
        tab.pasteInto();
    }

    // есть ли wtype в PATH (проба как в EmojiTab)
    Process {
        id: wtypeCheck
        command: ["sh", "-c", "command -v wtype >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => tab.haveWtype = exitCode === 0
    }

    // ── Закреплённые ──────────────────────────────────────────────────
    Text {
        visible: tab.fPins.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: Theme.dp(8)
        Layout.bottomMargin: Theme.dp(2)
        text: "Закреплённые"
        color: Theme.subtext
        font.family: Theme.textFont
        font.pixelSize: Theme.typeSize("labelMedium")
        font.weight: Theme.typeWeight("labelMedium")
    }

    Column { // пины: обычный позиционер надёжнее лэйаута с Repeater
        visible: tab.fPins.length > 0
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: tab.fPins

            delegate: ClipRow {
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
        // высота строго по содержимому (кап 340): нижняя граница в 96dp
        // оставляла фантомную пустую полосу под короткой историей.
        Layout.preferredHeight: Math.min(Theme.dp(340), contentHeight)
        model: tab.fItems
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds

        // последняя позиция скролла (не считая восстановление после сброса модели)
        property real _lastY: 0
        property bool _restoring: false
        onContentYChanged: if (!itemsView._restoring) itemsView._lastY = contentY

        delegate: ClipRow {
            baseIndex: tab.fPins.length
            selected: tab.sel === rowIndex
            onHovered: (i) => tab.hovered(i)
            onActivated: (i) => tab.activate(i)
        }
    }

    // fItems пересобирается при обновлении Clip.items — ListView сбрасывает
    // contentY в 0; запоминаем и возвращаем позицию (как ProcessesTab)
    Connections {
        target: Clip
        function onItemsChanged() {
            const y = itemsView._lastY;
            itemsView._restoring = true;
            Qt.callLater(function() {
                itemsView.contentY = Math.min(y, Math.max(0, itemsView.contentHeight - itemsView.height));
                itemsView._restoring = false;
            });
        }
    }

    Item { // пусто / нет результатов / загрузка
        visible: tab.count === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.dp(220)

        Text {
            anchors.centerIn: parent
            text: tab.query.trim() !== "" ? "Ничего не найдено"
                : (Clip.loading ? "Загрузка…" : "Буфер пуст")
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }
    }

    // ── Очистить историю: обычная строка-кнопка, тот же ритм ──────────
    Item {
        visible: Clip.items.length > 0
        Layout.fillWidth: true
        implicitHeight: Theme.dp(44)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: wipeArea.pressed ? Theme.a(Theme.errorContainer, 0.3)
                 : (wipeArea.containsMouse ? Theme.a(Theme.errorContainer, 0.2) : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.durQuick }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(4)
            anchors.rightMargin: Theme.dp(4)
            spacing: Theme.dp(4)

            Item { // слот превью — иконка в error-тоне по центру
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.dp(44)
                implicitHeight: Theme.dp(32)

                Icon {
                    anchors.centerIn: parent
                    name: "delete_sweep"
                    size: Theme.dp(16)
                    color: Theme.error
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: "Очистить историю"
                color: Theme.error
                elide: Text.ElideRight
                font.family: Theme.textFont
                font.pixelSize: Theme.typeSize("bodySmall")
                font.weight: Theme.typeWeight("bodySmall")
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

    // ── строка буфера: превью 44×32, текст, pin и delete справа ───────
    component ClipRow: ColumnLayout {
        id: ci

        required property var modelData
        required property int index

        property int baseIndex: 0
        property bool pinned: false
        property bool selected: false

        signal hovered(int rowIndex)
        signal activated(int rowIndex)

        readonly property int rowIndex: ci.baseIndex + ci.index
        readonly property bool isImage: !!ci.modelData && ci.modelData.type === "image"
        // в cliphist иногда попадает текст с NUL и управляющими байтами — чистим
        function clean(s) {
            return String(s === undefined || s === null ? "" : s)
                .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "");
        }
        readonly property string label: {
            if (!ci.modelData) return "";
            if (ci.modelData.type === "image") return "Изображение";
            const t = ci.clean(ci.modelData.text);
            if (t !== "") return t;
            return ci.clean(ci.modelData.preview);
        }

        // в Column ширина задаётся позиционером, в ListView — вью
        width: parent ? parent.width : implicitWidth
        Layout.fillWidth: true
        spacing: 0

        Divider { // между строками, кроме первой (верхней)
            visible: ci.rowIndex > 0
            Layout.fillWidth: true
            leftInset: Theme.dp(52)
        }

        Item {
            id: rowItem

            Layout.fillWidth: true
            implicitHeight: Theme.dp(48)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: ci.selected ? Theme.accentContainer
                     : (rowArea.containsMouse ? Theme.bgHover : "transparent")

                Behavior on color {
                    ColorAnimation { duration: Theme.durQuick }
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: ci.hovered(ci.rowIndex)
                onClicked: ci.activated(ci.rowIndex)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.dp(4)
                anchors.rightMargin: Theme.dp(4)
                spacing: Theme.dp(4)

                Item { // превью: картинка 44×32 либо просто иконка текста 16
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Theme.dp(44)
                    implicitHeight: Theme.dp(32)

                    Rectangle {
                        anchors.fill: parent
                        visible: ci.isImage
                        radius: Theme.radiusSm
                        color: Theme.bgTile
                        clip: true

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            // items кладут thumb (кэш по id), pins — file
                            source: ci.isImage && (ci.modelData.thumb || ci.modelData.file)
                                    ? "file://" + (ci.modelData.thumb || ci.modelData.file) : ""
                        }
                    }

                    Item { // текст: без контейнера, иконка по центру области 24
                        anchors.centerIn: parent
                        visible: !ci.isImage
                        implicitWidth: Theme.dp(24)
                        implicitHeight: Theme.dp(24)

                        Icon {
                            anchors.centerIn: parent
                            name: "description"
                            size: Theme.dp(16)
                            color: Theme.subtext
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: ci.label
                    color: ci.selected ? Theme.fgAccentContainer : Theme.text
                    // pins и короткие — одна строка, длинные — максимум две
                    elide: Text.ElideRight
                    wrapMode: ci.pinned ? Text.NoWrap : Text.Wrap
                    maximumLineCount: ci.pinned ? 1 : 2
                    font.family: Theme.textFont
                    font.pixelSize: Theme.typeSize("bodySmall")
                    font.weight: Theme.typeWeight("bodySmall")
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
                    implicitWidth: Theme.dp(28)
                    implicitHeight: Theme.dp(28)

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
                        size: Theme.dp(16)
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
