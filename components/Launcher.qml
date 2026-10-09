import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Блок лончера: поиск, чип скрытых и список приложений в карточке.
ColumnLayout {
    id: launcher
    property bool active: false
    property var shell: null
    // вкладка лончера: apps | clipboard | emoji (заполняется в волне 3)
    property string tab: "apps"

    visible: active
    Layout.fillWidth: true
    spacing: Theme.dp(14)

    property string query: ""
    property int sel: 0

    readonly property var apps: {
        const q = launcher.query.toLowerCase().trim();
        const out = [];
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            if (Apps.isHidden(a) && !Apps.showHidden) continue;
            const name = (a.name || "").toLowerCase();
            const comment = (a.comment || "").toLowerCase();
            const kwSrc = Array.isArray(a.keywords) ? a.keywords.join(" ") : (a.keywords || "");
            const kw = String(kwSrc).toLowerCase();
            if (q === "" || name.includes(q) || comment.includes(q) || kw.includes(q)) out.push(a);
        }
        out.sort((x, y) => {
            const px = Apps.isPinned(x), py = Apps.isPinned(y);
            if (px !== py) return px ? -1 : 1;
            return (x.name || "").localeCompare(y.name || "");
        });
        return out.slice(0, 60);
    }
    function launch(a) {
        if (!a) return;
        let cmd = a.command;
        if (typeof cmd === "string") cmd = ["sh", "-c", cmd];
        Quickshell.execDetached(cmd);
        if (launcher.shell) launcher.shell.closeOverlays();
    }
    onActiveChanged: {
        if (active) {
            launcher.query = "";
            launcher.sel = 0;
            searchField.text = ""; // не оставлять прошлый запрос в поле
        }
    }

    // Поиск: M3-поле; навигация клавишами — как раньше
    TextField {
        id: searchField
        Layout.fillWidth: true
        focus: launcher.active
        placeholder: "Поиск приложений…"
        onTextChanged: launcher.query = searchField.text
        onAccepted: launcher.launch(launcher.apps[launcher.sel])
        Keys.onEscapePressed: if (launcher.shell) launcher.shell.closeOverlays()
        Keys.onDownPressed: launcher.sel = Math.min(launcher.sel + 1, Math.max(0, launcher.apps.length - 1))
        Keys.onUpPressed: launcher.sel = Math.max(launcher.sel - 1, 0)
    }

    // Чип «Скрытые»: фильтр скрытых приложений
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Chip {
            label: "Скрытые (" + Apps.hidden.length + ")"
            icon: "visibility"
            selected: Apps.showHidden
            onClicked: Apps.showHidden = !Apps.showHidden
        }
    }

    // Список приложений в карточке; закреплённые — сверху
    Card {
        Layout.fillWidth: true

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.dp(400)
            model: launcher.apps
            clip: true
            spacing: 0

            delegate: Item {
                id: rowItem
                required property var modelData
                required property int index
                width: appList.width
                height: Theme.dp(52) + (index < launcher.apps.length - 1 ? 1 : 0)

                Rectangle {
                    id: row
                    width: parent.width
                    height: Theme.dp(52)
                    radius: Theme.radiusMd
                    color: rowItem.index === launcher.sel ? Theme.accentContainer
                                                          : (rowMouse.containsMouse ? Theme.bgHover : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Theme.durQuick }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: launcher.sel = rowItem.index
                        onClicked: launcher.launch(rowItem.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.dp(8)
                        anchors.rightMargin: Theme.dp(6)
                        spacing: Theme.dp(10)

                        // иконка приложения в контейнере с M3-радиусом
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Theme.dp(40)
                            Layout.preferredHeight: Theme.dp(40)
                            radius: Theme.radiusMd
                            color: Theme.bgTrack
                            Image {
                                anchors.centerIn: parent
                                width: Theme.dp(30)
                                height: Theme.dp(30)
                                sourceSize.width: 30
                                sourceSize.height: 30
                                smooth: true
                                source: rowItem.modelData.icon ? Quickshell.iconPath(rowItem.modelData.icon, true) : ""
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: rowItem.modelData.name || ""
                                color: rowItem.index === launcher.sel ? Theme.fgAccentContainer : Theme.text
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodyLarge")
                                font.weight: Theme.typeWeight("bodyLarge")
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: rowItem.modelData.comment || ""
                                color: rowItem.index === launcher.sel ? Theme.fgAccentContainer : Theme.subtext
                                opacity: rowItem.index === launcher.sel ? 0.75 : 1
                                font.family: Theme.textFont
                                font.pixelSize: Theme.typeSize("bodySmall")
                                font.weight: Theme.typeWeight("bodySmall")
                                elide: Text.ElideRight
                            }
                        }

                        // закрепить/открепить
                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "push_pin"
                            variant: Apps.isPinned(rowItem.modelData) ? "filled" : "standard"
                            onClicked: Apps.togglePin(rowItem.modelData)
                        }

                        // скрыть/показать
                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: Apps.isHidden(rowItem.modelData) ? "visibility_off" : "visibility"
                            variant: Apps.isHidden(rowItem.modelData) ? "filled" : "standard"
                            onClicked: Apps.toggleHide(rowItem.modelData)
                        }
                    }
                }

                // разделитель между строками, с отступом от иконки
                Divider {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: rowItem.index < launcher.apps.length - 1
                    leftInset: Theme.dp(58)
                    rightInset: Theme.dp(6)
                }
            }
        }
    }
}
