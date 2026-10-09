# Nimbus

Компактный desktop-shell на [Quickshell](https://quickshell.org) для композитора
**[Umbriel](https://github.com/noctalia-dev/umbriel)** в духе Dynamic Island.
**Всё взаимодействие — внутри одной пилюли** сверху по центру; отдельных панелей
снаружи нет.

## Запуск

```sh
quickshell -c nimbus        # вручную
```
Автозапуск: `~/.config/umbriel/src/general.toml` → `autostart`.

## Пилюля

- **Покой:** воркспейсы · время · 🔔 (колокольчик открывает панель управления).
- **Панель** (клик по 🔔 или `Mod+Escape`): часы/дата, плитки
  Wi-Fi / Bluetooth / DND / Lock, ползунки громкости и яркости, медиакарта,
  список уведомлений, кнопки питания (сон/выход/перезагрузка/выключение).
- **Лончер** (`Mod+Space`): поиск и запуск приложений — тоже в пилюле.
- **Обои** (`Mod+W`): вкладки **Фото / Видео / Wallhaven** (поиск, сортировка,
  категории, SFW/18+, разрешение, «Ещё»). Ставятся через `awww` (фото/гиф) или
  `mpvpaper` (видео); выбор сохраняется.
- **Цветовой акцент**: при смене обоев запускается `matugen` — палитра
  (акцент/поверхности/текст) обновляет и шелл, и систему (gtk/kitty/rofi/
  starship/Umbriel). Для видео акцент берётся из кадра (ffmpeg).
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
shell.qml                 корень: состояние (view), backdrop, острова, IPC
core/
  qmldir
  Theme.qml               цвета/метрики/шрифт
  Umbriel.qml             воркспейсы/окна (umbriel subscribe)
  Osd.qml                 состояние OSD
  Notif.qml               история уведомлений + тост + DND
  Sys.qml                 Wi-Fi/Bluetooth/яркость(DDC)/питание
  Wallpaper.qml           локальные/видео/Wallhaven + matugen-акцент
components/
  qmldir
  Island.qml              вся пилюля: idle/panel/launcher/osd/notif
  Lockscreen.qml          WlSessionLock + PAM
  Backdrop.qml            невидимый ловец кликов вне пилюли
```

## IPC

```sh
quickshell -c nimbus ipc call nimbus panel        # панель (toggle)
quickshell -c nimbus ipc call nimbus launcher     # лончер (toggle)
quickshell -c nimbus ipc call nimbus lock
quickshell -c nimbus ipc call nimbus volumeUp     # volumeDown, volumeMute
quickshell -c nimbus ipc call nimbus brightnessUp # brightnessDown
```
`quickshell -c nimbus ipc show` — список функций.

## Заметки

- Яркость — через `ddcutil` (внешний монитор по DDC/CI, `/dev/i2c-7`), т.к.
  backlight у десктопа нет. Применяется на отпускании ползунка (DDC небыстрый).
- Громкость — PipeWire (default sink), узел привязан через `PwObjectTracker`.
- Уведомление хранится снимком полей (живой D-Bus-объект в UI нестабилен).
