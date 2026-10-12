import QtQuick
import QtQuick.Layouts
import "../../core"
import ".."
import "../../ui" as Ui

// Обои: вкладки (ui/Tabs), фильтры, поиск и сетка превью. Вся логика — в Wallpaper.
ColumnLayout {
    id: wallpapersPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "wallpapers"
    Layout.fillWidth: true
    spacing: 10

    // вкладки в анатомии M3 (иконка/подпись + скользящий индикатор)
    Ui.Tabs {
        Layout.fillWidth: true
        options: [
            { "key": "photos", "label": "Фото" },
            { "key": "videos", "label": "Видео" },
            { "key": "motion", "label": "Motion" },
            { "key": "wallhaven", "label": "Wallhaven" }
        ]
        current: Wallpaper.tab
        onPicked: (key) => {
            Wallpaper.tab = key;
            if (key === "photos" || key === "videos") {
                if (Wallpaper.localItems.length === 0)
                    Wallpaper.refreshLocal();
            } else if (key === "motion") {
                if (Wallpaper.motionResults.length === 0) {
                    Wallpaper.motionQuery = "";
                    Wallpaper.searchMotion();
                }
            } else if (key === "wallhaven") {
                if (Wallpaper.results.length === 0)
                    Wallpaper.search();
            }
        }
    }

    RowLayout { // авто-смена и таймер + обновление
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

        Ui.LText {
            visible: Wallpaper.loading
            Layout.alignment: Qt.AlignVCenter
            role: "labelSmall"
            color: Theme.subtext
            text: "загрузка…"
        }

        Ui.IconButton {
            icon: "refresh"
            onClicked: Wallpaper.tab === "wallhaven" ? Wallpaper.search() : Wallpaper.refreshLocal()
        }
    }

    RowLayout { // значение таймера
        visible: win.showAuto
        Layout.fillWidth: true
        spacing: 8

        Ui.LText {
            role: "labelSmall"
            color: Theme.subtext
            text: "1м"
        }

        Ui.Slider {
            Layout.fillWidth: true
            value: (Wallpaper.autoMinutes - 1) / 1439
            onMoved: (v) => win.setAuto(v)
        }

        Ui.LText {
            role: "labelSmall"
            color: Theme.subtext
            text: "24ч"
        }

        Ui.LText {
            Layout.preferredWidth: 56
            horizontalAlignment: Text.AlignRight
            role: "labelSmall"
            color: Theme.text
            text: win.autoLabel
        }
    }

    Ui.TextField { // поиск
        visible: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
        variant: "search"
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
            id: cell

            required property var modelData

            readonly property bool selected: Wallpaper.tab !== "wallhaven" && Wallpaper.tab !== "motion" && Wallpaper.currentPath === modelData.path
            // wallhaven/motion отдают готовый thumb (картинка); локальные — путь к файлу
            readonly property bool useThumb: Wallpaper.tab === "wallhaven" || Wallpaper.tab === "motion"
            // локальное видео: Image не декодирует .mp4 — рисуем заглушку
            readonly property bool localVideo: !cell.useThumb && !!modelData.video

            width: 112
            height: 76
            radius: Theme.shapeLg
            color: Theme.bgTile
            clip: true
            scale: cell.selected ? 1.06 : 1
            z: cell.selected ? 2 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }
            }

            Image {
                anchors.fill: parent
                visible: !cell.localVideo
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: cell.localVideo ? "" : (cell.useThumb ? modelData.thumb : ("file://" + modelData.path))
            }

            Rectangle { // заглушка локального видео
                visible: cell.localVideo
                anchors.fill: parent
                color: Theme.bgTrack

                Ui.Icon {
                    anchors.centerIn: parent
                    name: "movie"
                    size: Theme.dp(26)
                    color: Theme.subtext
                }
            }

            Rectangle { // затемнение видео
                visible: Wallpaper.tab === "motion" || cell.localVideo
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

            Rectangle { // выбранное: рамка accent 2
                visible: cell.selected
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
            }

            Rectangle { // галочка выбранного в углу
                visible: cell.selected
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.dp(4)
                width: Theme.dp(22)
                height: Theme.dp(22)
                radius: Theme.radiusPill
                color: Theme.accentContainer
                border.width: 1
                border.color: Theme.a(Theme.accent, 0.45)

                Ui.Icon {
                    anchors.centerIn: parent
                    name: "check"
                    size: Theme.dp(14)
                    color: Theme.fgAccentContainer
                }
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

        Ui.LText {
            anchors.centerIn: parent
            visible: wpGrid.count === 0
            role: "bodyMedium"
            color: Theme.subtext
            text: Wallpaper.loading ? "Загрузка…" : "Пусто"
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
