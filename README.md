# Nimbus

Компактный desktop-shell на [Quickshell](https://quickshell.org) для композитора
**[Umbriel](https://github.com/noctalia-dev/umbriel)** (от авторов Noctalia) в духе
Dynamic Island, оформленный в **Material 3 Expressive**.
**Всё взаимодействие — внутри одной пилюли** сверху по центру; отдельных панелей
снаружи нет.

## Живёт отдельно

Nimbus не зависит ни от Lucid, ни от Hyprland, ни от `~/.config/quickshell`, ни от
`~/.config/matugen`. Он лежит целиком в этом репозитории (по умолчанию `~/nimbus`),
запускается по пути и владеет своим matugen-конфигом:

```sh
qs -p ~/nimbus                # вручную (или quickshell -p /home/tony/nimbus)
```

Автозапуск: `~/.config/umbriel/src/general.toml` → `/usr/bin/qs -p /home/tony/nimbus`.
Кейбинды: `~/.config/umbriel/src/keybinds.toml` → `qs -p /home/tony/nimbus ipc call nimbus …`.

Удалишь Hyprland, Lucid и `~/.config/quickshell` — Nimbus продолжит работать.

## Пилюля

- **Покой:** воркспейсы · время · 🔔 (колокольчик открывает панель управления).
- **Панель** (клик по 🔔 или `Mod+Escape`): часы/дата, плитки
  Wi-Fi / Bluetooth / Звук / Яркость / DND / Обои, медиакарта,
  список уведомлений, кнопки питания (сон/выход/перезагрузка/выключение).
- **Лончер** (`Mod+Space`): поиск и запуск приложений — тоже в пилюле.
- **Обои** (`Mod+W`): вкладки **Фото / Видео / Motion / Wallhaven** (поиск, сортировка,
  категории, SFW/18+, разрешение, «Ещё», авто-смена). Ставятся через `awww` (фото/гиф) или
  `mpvpaper` (видео); выбор сохраняется.
- **Цветовой акцент**: при смене обоев запускается `matugen` со **своим** конфигом
  (`~/nimbus/matugen/config.toml`) — палитра обновляет и шелл, и систему
  (gtk/kitty/rofi/starship/Umbriel). Для видео акцент берётся из кадра (ffmpeg).
- **OSD**: всплывает при изменении громкости/яркости, когда пилюля в покое.
- **Тост**: новое уведомление показывается в пилюле.
- Клик **вне** пилюли закрывает панель/лончер (невидимый backdrop).

## Управление (кейбинды Umbriel)

| Клавиши | Действие |
| --- | --- |
| `Mod+Space` | Лончер приложений (закреп/скрытие приложений) |
| `Mod+Escape` | Панель управления |
| `Mod+W` | Обои (Фото / Видео / Motion / Wallhaven, авто-смена) |
| `Mod+V` | Буфер обмена (текст+изображения, закрепление) |
| `Print` | Скриншот области |
| `Shift+Print` | Скриншот всего экрана |
| `Mod+L` | Блокировка экрана |
| `Mod+Alt+BackSpace` | Выход из сессии |
| `XF86Audio*` / `XF86MonBrightness*` | Громкость/яркость + OSD |

> `Mod` = **Super**.

## Состав

```
shell.qml                 корень: состояние (view), backdrop, острова, IPC, PAM
core/
  qmldir
  Theme.qml               M3-движок: палитра, тональные рампы, типографика, motion, формы
  Umbriel.qml             воркспейсы/окна (umbriel subscribe)
  Osd.qml                 состояние OSD
  Notif.qml               история уведомлений + тост + DND
  Sys.qml                 Wi-Fi/Bluetooth/яркость(DDC)/питание
  Wallpaper.qml           локальные/видео/Wallhaven/MotionBGs + matugen-акцент
  Clip.qml, Apps.qml      история буфера и состояние лончера
ui/                       M3-примитивы
  Icon.qml, Glyphs.js     иконки Material Symbols (кодпоинты из бандленного шрифта)
  Button, IconButton, Slider, Switch, Chip, TextField, Divider, Badge
components/
  qmldir
  Island.qml              сборка пилюли: idle/панель/лончер
  IdlePill, OsdRow, NotifToastRow, MediaCard, WorkspacesRow
  Launcher.qml, Lockscreen.qml, Backdrop.qml
  Tile, ToggleRow, DeviceRow, PowerRow, NotifItem, SliderRow, ClipRow, TabBtn
  panel/                  страницы панели: RootPage, WifiPage, BtPage, VolumePage,
                          BrightnessPage, WallpapersPage, ClipboardPage, PowerPage
matugen/                  свой конфиг и шаблоны (matugen -c ~/nimbus/matugen/config.toml)
assets/fonts/             MaterialSymbolsRounded.ttf (бандл, чтобы не зависеть от системы)
tools/gen-glyphs.py       генератор ui/Glyphs.js из шрифта
scripts/                  clip-pin.sh, clip-unpin.sh
```

## Цвета

Палитра — полный набор Material 3 (36 ролей) из `~/.cache/nimbus/colors.json`,
который пишет `matugen -c ~/nimbus/matugen/config.toml`. `core/Theme.qml` сам следит
за файлом (FileView) и выводит из сырых ролей тональные рампы, контейнеры, статусы,
типографику, motion-кривые и формы. Смена обоев — мгновенно, без перезапуска.

## IPC

```sh
qs -p ~/nimbus ipc call nimbus panel        # панель (toggle)
qs -p ~/nimbus ipc call nimbus launcher     # лончер (toggle)
qs -p ~/nimbus ipc call nimbus lock
qs -p ~/nimbus ipc call nimbus volumeUp     # volumeDown, volumeMute
qs -p ~/nimbus ipc call nimbus brightnessUp # brightnessDown
qs -p ~/nimbus ipc call nimbus pageWifi     # pageBluetooth, pageVolume, pageBrightness, pagePower
qs -p ~/nimbus ipc call nimbus wallpapers   # clipboard
qs -p ~/nimbus ipc call nimbus screenshotRegion  # screenshotFull, wpMotion, wpWallhaven
```
`qs -p ~/nimbus ipc show` — список функций.

## Заметки

- Яркость — через `ddcutil` (внешний монитор по DDC/CI, `/dev/i2c-7`), т.к.
  backlight у десктопа нет. Применяется на отпускании ползунка (DDC небыстрый).
- Громкость — PipeWire (default sink), узел привязан через `PwObjectTracker`.
- Уведомление хранится снимком полей (живой D-Bus-объект в UI нестабилен).
- Иконки — Material Symbols Rounded; карта кодпоинтов генерируется
  `tools/gen-glyphs.py` из бандленного шрифта.
