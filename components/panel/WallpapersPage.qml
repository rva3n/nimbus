import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui" as Ui

// Обои: табы, фильтры, поиск и сетка превью. Вся логика — в Wallpaper.
ColumnLayout {
    id: wallpapersPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "wallpapers"
    Layout.fillWidth: true
    spacing: 10

    RowLayout { // табы + обновление
        Layout.fillWidth: true
        spacing: 8

        TabBtn { label: "Фото"; active: Wallpaper.tab === "photos"; onClicked: { Wallpaper.tab = "photos"; if (Wallpaper.localItems.length === 0) Wallpaper.refreshLocal(); } }
        TabBtn { label: "Видео"; active: Wallpaper.tab === "videos"; onClicked: { Wallpaper.tab = "videos"; if (Wallpaper.localItems.length === 0) Wallpaper.refreshLocal(); } }
        TabBtn { label: "Motion"; active: Wallpaper.tab === "motion"; onClicked: { Wallpaper.tab = "motion"; if (Wallpaper.motionResults.length === 0) { Wallpaper.motionQuery = ""; Wallpaper.searchMotion(); } } }
        TabBtn { label: "Wallhaven"; active: Wallpaper.tab === "wallhaven"; onClicked: { Wallpaper.tab = "wallhaven"; if (Wallpaper.results.length === 0) Wallpaper.search(); } }

        Item { Layout.fillWidth: true }

        Text {
            visible: Wallpaper.loading
            Layout.alignment: Qt.AlignVCenter
            text: "загрузка…"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }

        Ui.IconButton {
            icon: "refresh"
            onClicked: Wallpaper.tab === "wallhaven" ? Wallpaper.search() : Wallpaper.refreshLocal()
        }
    }

    RowLayout { // авто-смена и таймер
        Layout.fillWidth: true
        spacing: 6

        Ui.Chip {
            label: Wallpaper.autoEnabled ? "Авто: вкл" : "Авто: выкл"
            selected: Wallpaper.autoEnabled
            onClicked: { Wallpaper.autoEnabled = !Wallpaper.autoEnabled; Wallpaper.saveState(); }
        }

        Ui.Chip {
            label: "Таймер: " + win.autoLabel
            selected: win.showAuto
            onClicked: win.showAuto = !win.showAuto
        }

        Item { Layout.fillWidth: true }
    }

    RowLayout { // значение таймера
        visible: win.showAuto
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "1м"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }

        Ui.Slider {
            Layout.fillWidth: true
            value: (Wallpaper.autoMinutes - 1) / 1439
            onMoved: (v) => win.setAuto(v)
        }

        Text {
            text: "24ч"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }

        Text {
            Layout.preferredWidth: 56
            horizontalAlignment: Text.AlignRight
            text: win.autoLabel
            color: Theme.text
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("labelSmall")
            font.weight: Theme.typeWeight("labelSmall")
        }
    }

    Ui.TextField { // поиск
        visible: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
        Layout.fillWidth: true
        placeholder: Wallpaper.tab === "motion" ? "Поиск видео (MotionBGs)…" : "Поиск на Wallhaven…"
        onAccepted: {
            if (Wallpaper.tab === "motion") {
                Wallpaper.motionQuery = text;
                Wallpaper.searchMotion();
            } else {
                Wallpaper.query = text;
                Wallpaper.search();
            }
        }
    }

    ColumnLayout { // фильтры Wallhaven
        visible: Wallpaper.tab === "wallhaven"
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            spacing: 6

            Ui.Chip { label: "Топ"; selected: Wallpaper.sorting === "toplist"; onClicked: { Wallpaper.sorting = "toplist"; Wallpaper.search(); } }
            Ui.Chip { label: "Новые"; selected: Wallpaper.sorting === "date_added"; onClicked: { Wallpaper.sorting = "date_added"; Wallpaper.search(); } }
            Ui.Chip { label: "Случайные"; selected: Wallpaper.sorting === "random"; onClicked: { Wallpaper.sorting = "random"; Wallpaper.search(); } }
        }

        RowLayout {
            spacing: 6

            Ui.Chip { label: "Общие"; selected: Wallpaper.category === "general"; onClicked: { Wallpaper.category = "general"; Wallpaper.search(); } }
            Ui.Chip { label: "Аниме"; selected: Wallpaper.category === "anime"; onClicked: { Wallpaper.category = "anime"; Wallpaper.search(); } }
            Ui.Chip { label: "Люди"; selected: Wallpaper.category === "people"; onClicked: { Wallpaper.category = "people"; Wallpaper.search(); } }
            Ui.Chip { label: "Все"; selected: Wallpaper.category === "all"; onClicked: { Wallpaper.category = "all"; Wallpaper.search(); } }
        }

        RowLayout {
            spacing: 6

            Ui.Chip { label: "SFW"; selected: Wallpaper.purity === "sfw"; onClicked: { Wallpaper.purity = "sfw"; Wallpaper.search(); } }
            Ui.Chip { label: "18+"; selected: Wallpaper.purity === "sketchy"; onClicked: { Wallpaper.purity = "sketchy"; Wallpaper.search(); } }
            Ui.Chip { label: "FHD"; selected: Wallpaper.minRes === "1920x1080"; onClicked: { Wallpaper.minRes = "1920x1080"; Wallpaper.search(); } }
            Ui.Chip { label: "2K"; selected: Wallpaper.minRes === "2560x1440"; onClicked: { Wallpaper.minRes = "2560x1440"; Wallpaper.search(); } }
            Ui.Chip { label: "4K"; selected: Wallpaper.minRes === "3840x2160"; onClicked: { Wallpaper.minRes = "3840x2160"; Wallpaper.search(); } }
        }
    }

    GridView {
        id: wpGrid

        Layout.fillWidth: true
        Layout.preferredHeight: 360
        clip: true
        cellWidth: 120
        cellHeight: 84

        onContentYChanged: if (Wallpaper.tab === "motion" && contentY + height >= contentHeight - 220) Wallpaper.loadMoreMotion()

        model: Wallpaper.tab === "photos" ? Wallpaper.photos
             : Wallpaper.tab === "videos" ? Wallpaper.videos
             : Wallpaper.tab === "motion" ? Wallpaper.motionResults
             : Wallpaper.results

        delegate: Rectangle {
            required property var modelData

            width: 112
            height: 76
            radius: Theme.radiusMd
            color: Theme.bgTile
            clip: true

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: (Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion") ? modelData.thumb : ("file://" + modelData.path)
            }

            Rectangle { // затемнение видео
                visible: Wallpaper.tab === "motion" || (Wallpaper.tab !== "wallhaven" && modelData.video)
                anchors.fill: parent
                radius: parent.radius
                color: Theme.alpha(Theme.shadow, 0.45)

                Ui.Icon {
                    anchors.centerIn: parent
                    name: "play_circle"
                    size: Theme.dp(24)
                    color: Theme.text
                }
            }

            Rectangle { // ховер
                anchors.fill: parent
                radius: parent.radius
                color: Theme.text
                opacity: wpMouse.containsMouse ? Theme.stateHover : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(100)
                        easing.type: Theme.easeStandard
                    }
                }
            }

            Rectangle { // выбранное
                visible: Wallpaper.tab !== "wallhaven" && Wallpaper.tab !== "motion" && Wallpaper.currentPath === modelData.path
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
            }

            MouseArea {
                id: wpMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingCursor
                onClicked: {
                    if (Wallpaper.tab === "wallhaven")
                        Wallpaper.applyUrl(modelData);
                    else if (Wallpaper.tab === "motion")
                        Wallpaper.applyVideoUrl(modelData.video);
                    else
                        Wallpaper.apply(modelData.path, modelData.video);
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: wpGrid.count === 0
            text: Wallpaper.loading ? "Загрузка…" : "Пусто"
            color: Theme.subtext
            font.family: Theme.textFont
            font.pixelSize: Theme.typeSize("bodyMedium")
            font.weight: Theme.typeWeight("bodyMedium")
        }
    }

    RowLayout { // «Ещё»
        visible: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
        Layout.fillWidth: true

        Item { Layout.fillWidth: true }

        Ui.Chip {
            label: "Ещё"
            onClicked: Wallpaper.tab === "motion" ? Wallpaper.loadMoreMotion() : Wallpaper.nextPage()
        }
    }
}
