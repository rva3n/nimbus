import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."

ColumnLayout {
    id: wallpapersPage
    property var win: null
    visible: win !== null && win.mode === "panel" && win.page === "wallpapers"
    Layout.fillWidth: true; spacing: 10

    RowLayout {
        Layout.fillWidth: true; spacing: 8
        TabBtn { label: "Фото"; active: Wallpaper.tab === "photos"; onClicked: { Wallpaper.tab = "photos"; if (Wallpaper.localItems.length === 0) Wallpaper.refreshLocal(); } }
        TabBtn { label: "Видео"; active: Wallpaper.tab === "videos"; onClicked: { Wallpaper.tab = "videos"; if (Wallpaper.localItems.length === 0) Wallpaper.refreshLocal(); } }
        TabBtn { label: "Motion"; active: Wallpaper.tab === "motion"; onClicked: { Wallpaper.tab = "motion"; if (Wallpaper.motionResults.length === 0) { Wallpaper.motionQuery = ""; Wallpaper.searchMotion(); } } }
        TabBtn { label: "Wallhaven"; active: Wallpaper.tab === "wallhaven"; onClicked: { Wallpaper.tab = "wallhaven"; if (Wallpaper.results.length === 0) Wallpaper.search(); } }
        Item { Layout.fillWidth: true }
        Text { visible: Wallpaper.loading; font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "загрузка…" }
        IconBtn { glyph: "\uf021"; onClicked: Wallpaper.tab === "wallhaven" ? Wallpaper.search() : Wallpaper.refreshLocal() }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 6
        Chip { label: Wallpaper.autoEnabled ? "Авто: вкл" : "Авто: выкл"; active: Wallpaper.autoEnabled; onClicked: { Wallpaper.autoEnabled = !Wallpaper.autoEnabled; Wallpaper.saveState(); } }
        Chip { label: "Таймер: " + win.autoLabel; active: win.showAuto; onClicked: win.showAuto = !win.showAuto }
        Item { Layout.fillWidth: true }
    }
    RowLayout {
        visible: win.showAuto
        Layout.fillWidth: true; spacing: 8
        Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "1м" }
        Item {
            Layout.fillWidth: true; implicitHeight: 24
            Rectangle {
                id: atrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: 3; color: Theme.surfaceHi
                Rectangle {
                    width: parent.width * ((Wallpaper.autoMinutes - 1) / 1439)
                    height: parent.height; radius: 3; color: Theme.accent
                }
            }
            MouseArea {
                anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6
                onPressed: (m) => win.setAuto(m.x / atrack.width)
                onPositionChanged: (m) => win.setAuto(m.x / atrack.width)
            }
        }
        Text { font.family: Theme.font; font.pixelSize: 11; color: Theme.subtext; text: "24ч" }
        Text {
            Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight
            font.family: Theme.font; font.pixelSize: 11; color: Theme.text; text: win.autoLabel
        }
    }

    TextInput {
        visible: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
        Layout.fillWidth: true; Layout.preferredHeight: 32
        font.family: Theme.font; font.pixelSize: 14; color: Theme.text
        clip: true; selectByMouse: true
        onAccepted: {
            if (Wallpaper.tab === "motion") { Wallpaper.motionQuery = text; Wallpaper.searchMotion(); }
            else { Wallpaper.query = text; Wallpaper.search(); }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.text === ""
            text: Wallpaper.tab === "motion" ? "Поиск видео (MotionBGs)…" : "Поиск на Wallhaven…"
            color: Theme.a(Theme.subtext, 0.5); font: parent.font
        }
    }

    ColumnLayout {
        visible: Wallpaper.tab === "wallhaven"
        Layout.fillWidth: true; spacing: 6
        RowLayout {
            spacing: 6
            Chip { label: "Топ"; active: Wallpaper.sorting === "toplist"; onClicked: { Wallpaper.sorting = "toplist"; Wallpaper.search(); } }
            Chip { label: "Новые"; active: Wallpaper.sorting === "date_added"; onClicked: { Wallpaper.sorting = "date_added"; Wallpaper.search(); } }
            Chip { label: "Случайные"; active: Wallpaper.sorting === "random"; onClicked: { Wallpaper.sorting = "random"; Wallpaper.search(); } }
        }
        RowLayout {
            spacing: 6
            Chip { label: "Общие"; active: Wallpaper.category === "general"; onClicked: { Wallpaper.category = "general"; Wallpaper.search(); } }
            Chip { label: "Аниме"; active: Wallpaper.category === "anime"; onClicked: { Wallpaper.category = "anime"; Wallpaper.search(); } }
            Chip { label: "Люди"; active: Wallpaper.category === "people"; onClicked: { Wallpaper.category = "people"; Wallpaper.search(); } }
            Chip { label: "Все"; active: Wallpaper.category === "all"; onClicked: { Wallpaper.category = "all"; Wallpaper.search(); } }
        }
        RowLayout {
            spacing: 6
            Chip { label: "SFW"; active: Wallpaper.purity === "sfw"; onClicked: { Wallpaper.purity = "sfw"; Wallpaper.search(); } }
            Chip { label: "18+"; active: Wallpaper.purity === "sketchy"; onClicked: { Wallpaper.purity = "sketchy"; Wallpaper.search(); } }
            Chip { label: "FHD"; active: Wallpaper.minRes === "1920x1080"; onClicked: { Wallpaper.minRes = "1920x1080"; Wallpaper.search(); } }
            Chip { label: "2K"; active: Wallpaper.minRes === "2560x1440"; onClicked: { Wallpaper.minRes = "2560x1440"; Wallpaper.search(); } }
            Chip { label: "4K"; active: Wallpaper.minRes === "3840x2160"; onClicked: { Wallpaper.minRes = "3840x2160"; Wallpaper.search(); } }
        }
    }

    GridView {
        id: wpGrid
        Layout.fillWidth: true
        Layout.preferredHeight: 360
        clip: true
        cellWidth: 120; cellHeight: 84
        onContentYChanged: if (Wallpaper.tab === "motion" && contentY + height >= contentHeight - 220) Wallpaper.loadMoreMotion()
        model: Wallpaper.tab === "photos" ? Wallpaper.photos
             : Wallpaper.tab === "videos" ? Wallpaper.videos
             : Wallpaper.tab === "motion" ? Wallpaper.motionResults
             : Wallpaper.results
        delegate: Rectangle {
            required property var modelData
            width: 112; height: 76; radius: 10
            color: Theme.surface; clip: true
            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: (Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion") ? modelData.thumb : ("file://" + modelData.path)
            }
            Rectangle {
                visible: Wallpaper.tab === "motion" || (Wallpaper.tab !== "wallhaven" && modelData.video)
                anchors.fill: parent; color: Theme.a("#000000", 0.4)
                Text { anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: 20; color: Theme.text; text: "\uf03d" }
            }
            Rectangle {
                visible: Wallpaper.tab !== "wallhaven" && Wallpaper.tab !== "motion" && Wallpaper.currentPath === modelData.path
                anchors.fill: parent; radius: 10; color: "transparent"
                border.width: 2; border.color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onClicked: {
                    if (Wallpaper.tab === "wallhaven") Wallpaper.applyUrl(modelData);
                    else if (Wallpaper.tab === "motion") Wallpaper.applyVideoUrl(modelData.video);
                    else Wallpaper.apply(modelData.path, modelData.video);
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: wpGrid.count === 0
            font.family: Theme.font; font.pixelSize: 12; color: Theme.subtext
            text: Wallpaper.loading ? "Загрузка…" : "Пусто"
        }
    }

    RowLayout {
        visible: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Chip { label: "Ещё"; onClicked: Wallpaper.tab === "motion" ? Wallpaper.loadMoreMotion() : Wallpaper.nextPage() }
    }
}
