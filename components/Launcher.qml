import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"

// Launcher block: search field, hidden-apps chip, application list.
ColumnLayout {
    id: launcher
    property bool active: false
    property var shell: null

    visible: active
    Layout.fillWidth: true
    spacing: 14

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
    onActiveChanged: if (active) { launcher.query = ""; launcher.sel = 0; }

    TextInput {
        id: search
        visible: launcher.active
        Layout.fillWidth: true; Layout.preferredHeight: 34
        font.family: Theme.font; font.pixelSize: 18; color: Theme.text
        clip: true; selectByMouse: true
        focus: launcher.active
        onTextChanged: launcher.query = text
        Keys.onEscapePressed: if (launcher.shell) launcher.shell.closeOverlays()
        Keys.onDownPressed: launcher.sel = Math.min(launcher.sel + 1, Math.max(0, launcher.apps.length - 1))
        Keys.onUpPressed: launcher.sel = Math.max(launcher.sel - 1, 0)
        Keys.onReturnPressed: launcher.launch(launcher.apps[launcher.sel])
        Keys.onEnterPressed: launcher.launch(launcher.apps[launcher.sel])
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: search.text === ""
            text: "Поиск приложений…"; color: Theme.a(Theme.subtext, 0.5); font: search.font
        }
    }
    RowLayout {
        visible: launcher.active
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Chip {
            label: "Скрытые (" + Apps.hidden.length + ")"
            active: Apps.showHidden
            onClicked: Apps.showHidden = !Apps.showHidden
        }
    }
    ListView {
        id: appList
        visible: launcher.active
        Layout.fillWidth: true; Layout.preferredHeight: 400
        model: launcher.apps; clip: true; spacing: 2
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: appList.width; height: 46; radius: 10
            color: index === launcher.sel ? Theme.a(Theme.accent, 0.15) : "transparent"
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onEntered: launcher.sel = index
                onClicked: launcher.launch(modelData)
            }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 10
                Image {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    sourceSize.width: 26; sourceSize.height: 26
                    source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: modelData.name || ""; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: modelData.comment || ""; visible: text !== ""; color: Theme.subtext; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                Text {
                    visible: Apps.isPinned(modelData)
                    font.family: Theme.font; font.pixelSize: 11; color: Theme.accent; text: "\uf08d"
                }
                RoundBtn { glyph: "\uf08d"; active: Apps.isPinned(modelData); onClicked: Apps.togglePin(modelData) }
                RoundBtn { glyph: Apps.isHidden(modelData) ? "\uf06e" : "\uf070"; active: Apps.isHidden(modelData); onClicked: Apps.toggleHide(modelData) }
            }
        }
    }
}
