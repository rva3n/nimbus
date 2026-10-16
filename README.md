# Oberon

Material 3 Expressive desktop shell (dynamic island) for the [Umbriel](https://github.com/rva3n) Wayland
compositor, built on a vendored fork of Quickshell. Дизайн портирован из Lucid.

Всё своё: рантайм и утилиты собираются из сабмодулей `third_party/` (форки под
[rva3n](https://github.com/rva3n)) — из системного нужны только Qt6, PipeWire/Polkit-
библиотеки и обычные CLI-утилиты (см. список в `install.sh`).

## Установка

```sh
curl -fsSL https://raw.githubusercontent.com/rva3n/oberon/main/install.sh | sh
```

Флаги передаются через `sh -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/rva3n/oberon/main/install.sh | sh -s -- --start
```

Скрипт (Arch Linux):

1. ставит системные зависимости через pacman (`--needed`);
2. клонирует репо в `~/oberon` (**путь зашит в шелле** — не переезжай);
3. собирает вендорный стек в `build/prefix/bin` (первый раз ~10–20 минут);
4. прописывает автозапуск и биндинги в конфиги Umbriel (с бэкапами `*.bak-<дата>`);
5. по флагу `--start` запускает шелл.

Флаги: `--no-deps`, `--no-build`, `--no-wire`, `--start`.

## Структура

- `shell.qml`, `core/`, `components/`, `ui/` — шелл (QML);
- `third_party/` — сабмодули-форки с переименованием:
  quickshell → **oberonqs**, matugen → **oberoncolor**, awww → **oberonwall**,
  cava → **oberoncava**, hypridle → **oberonidle**
  (+ build-зависимости: cli11, vulkan-headers, hyprwayland-scanner, hyprland-protocols);
- `wallpapers/` — сабмодуль [rva3n/oberon-wallpapers](https://github.com/rva3n/oberon-wallpapers);
- `scripts/` — сервисные скрипты (тема, idle, скриншоты) и `scripts/build-deps.sh`.

## Обновление

Повторить установочную команду: сделает `git pull`, обновит сабмодули и
инкрементально пересоберёт. Конфиги Umbriel правятся только если в них ещё
остались неприменённые паттерны (повторные запуски ничего не ломают).

## Лицензии

См. `LICENSE` и `licenses/THIRD-PARTY.md`.
