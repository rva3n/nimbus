import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"
import ".."

// Страница «Игры»: MangoHud — оверлей для мониторинга FPS, CPU, GPU и RAM в играх.
// Конфигурация хранится в Prefs и применяется к ~/.config/MangoHud/MangoHud.conf.
ColumnLayout {
    id: gamesPage

    property var win: null

    visible: win !== null && win.mode === "panel" && win.page === "games"
    Layout.fillWidth: true
    spacing: Theme.dp(12)

    LText {
        role: "titleMedium"
        color: Theme.text
        text: "Игры"
    }
    LText {
        Layout.fillWidth: true
        role: "bodySmall"
        color: Theme.subtext
        wrapMode: Text.WordWrap
        text: "MangoHud — оверлей с метриками производительности в играх"
    }

    Card {
        Layout.fillWidth: true

        ToggleRow {
            label: "MangoHud"
            sub: "Показывать оверлей с метриками в играх (FPS, CPU, GPU и т.д.)"
            checked: Prefs.mangohudEnabled
            onToggled: (v) => {
                Prefs.set("mangohudEnabled", v);
                gamesPage.scheduleMangoHudApply();
            }
        }
    }

    Card {
        Layout.fillWidth: true
        title: "Элементы оверлея"

        LText {
            role: "labelSmall"
            color: Theme.subtext
            text: "ОСНОВНЫЕ МЕТРИКИ"
            Layout.topMargin: Theme.dp(8)
            Layout.bottomMargin: Theme.dp(4)
        }
        ToggleRow {
            label: "FPS"
            sub: "Кадры в секунду"
            checked: Prefs.mangohudFPS
            onToggled: (v) => { Prefs.set("mangohudFPS", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "CPU"
            sub: "Загрузка процессора"
            checked: Prefs.mangohudCPU
            onToggled: (v) => { Prefs.set("mangohudCPU", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "GPU"
            sub: "Загрузка видеокарты"
            checked: Prefs.mangohudGPU
            onToggled: (v) => { Prefs.set("mangohudGPU", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "RAM"
            sub: "Использование оперативной памяти"
            checked: Prefs.mangohudRAM
            onToggled: (v) => { Prefs.set("mangohudRAM", v); gamesPage.scheduleMangoHudApply(); }
        }

        LText {
            role: "labelSmall"
            color: Theme.subtext
            text: "ДОПОЛНИТЕЛЬНО"
            Layout.topMargin: Theme.dp(8)
            Layout.bottomMargin: Theme.dp(4)
        }
        ToggleRow {
            label: "VRAM"
            sub: "Использование видеопамяти"
            checked: Prefs.mangohudVRAM
            onToggled: (v) => { Prefs.set("mangohudVRAM", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "Время кадра"
            sub: "Frame time в миллисекундах"
            checked: Prefs.mangohudFrameTime
            onToggled: (v) => { Prefs.set("mangohudFrameTime", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "Версия MangoHud"
            sub: "Показывать версию в углу оверлея"
            checked: Prefs.mangohudVersion
            onToggled: (v) => { Prefs.set("mangohudVersion", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "Движок игры"
            sub: "Название графического API и движка"
            checked: Prefs.mangohudEngine
            onToggled: (v) => { Prefs.set("mangohudEngine", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "Ввод-вывод"
            sub: "Статистика дискового I/O"
            checked: Prefs.mangohudIO
            onToggled: (v) => { Prefs.set("mangohudIO", v); gamesPage.scheduleMangoHudApply(); }
        }
        ToggleRow {
            label: "Медиа"
            sub: "Информация о воспроизводимом медиа"
            checked: Prefs.mangohudMedia
            onToggled: (v) => { Prefs.set("mangohudMedia", v); gamesPage.scheduleMangoHudApply(); }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.dp(8)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                LText {
                    role: "bodyMedium"
                    color: Theme.text
                    text: "Прозрачность оверлея"
                }
                LText {
                    role: "bodySmall"
                    color: Theme.subtext
                    text: "0% — полностью прозрачный, 100% — непрозрачный"
                }
            }
            LText {
                role: "labelLarge"
                color: Theme.text
                text: Math.round(Prefs.mangohudHudAlpha * 100) + "%"
            }
            Slider {
                id: hudAlphaSlider
                Layout.preferredWidth: Theme.dp(160)
                from: 0
                to: 1
                value: Prefs.mangohudHudAlpha
                onMoved: (v) => {
                    const rounded = Math.round(v * 100) / 100;
                    Prefs.set("mangohudHudAlpha", rounded);
                }
                onCommitted: (v) => gamesPage.scheduleMangoHudApply()
            }
        }
    }

    Timer {
        id: mangoHudApplyTimer
        interval: 500
        onTriggered: if (!hudAlphaSlider.dragging) gamesPage.applyMangoHud()
    }

    function scheduleMangoHudApply() {
        mangoHudApplyTimer.restart();
    }

    // Применить настройки MangoHud: записать конфиг в ~/.config/MangoHud/MangoHud.conf
    function applyMangoHud() {
        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/oberon/scripts/apply-mangohud.sh"]);
    }

    Component.onCompleted: {
        gamesPage.applyMangoHud();
    }
}
