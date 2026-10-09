import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Launcher block: search field, hidden-apps chip, application list.
ColumnLayout {
    id: launcher
    property bool active: false
    property var shell: null

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

    // Список приложений; закреплённые — сверху
    ListView {
        id: appList
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.dp(400)
        model: launcher.apps
        clip: true
        spacing: Theme.dp(2)
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: appList.width
            height: Theme.dp(52)
            radius: Theme.radiusMd
            color: index === launcher.sel ? Theme.accentContainer
                                          : (rowMouse.containsMouse ? Theme.bgHover : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.durQuick }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: launcher.sel = index
                onClicked: launcher.launch(modelData)
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
                    color: Theme.bgTile
                    Image {
                        anchors.centerIn: parent
                        width: Theme.dp(30)
                        height: Theme.dp(30)
                        sourceSize.width: 30
                        sourceSize.height: 30
                        smooth: true
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name || ""
                        color: Theme.text
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("bodyLarge")
                        font.weight: Theme.typeWeight("bodyLarge")
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: modelData.comment || ""
                        color: Theme.subtext
                        font.family: Theme.textFont
                        font.pixelSize: Theme.typeSize("bodySmall")
                        font.weight: Theme.typeWeight("bodySmall")
                        elide: Text.ElideRight
                    }
                }

                // метка закрепа
                Icon {
                    Layout.alignment: Qt.AlignVCenter
                    visible: Apps.isPinned(modelData)
                    name: "push_pin"
                    size: Theme.dp(14)
                    color: Theme.accent
                }

                // закрепить/открепить
                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "push_pin"
                    variant: Apps.isPinned(modelData) ? "filled" : "standard"
                    onClicked: Apps.togglePin(modelData)
                }

                // скрыть/показать
                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: Apps.isHidden(modelData) ? "visibility_off" : "visibility"
                    variant: Apps.isHidden(modelData) ? "filled" : "standard"
                    onClicked: Apps.toggleHide(modelData)
                }
            }
        }
    }
}
