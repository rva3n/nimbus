#!/bin/sh
# Oberon: пипетка — точечный slurp (-p) → grim 1x1 → magick читает пиксель,
# hex уходит в wl-copy + тост с подложкой цвета.
set -u

sleep 0.25
# необязательный аргумент "X,Y WxH" (для тестов); по умолчанию slurp -p
POS="${1:-}"
[ -n "$POS" ] || { POS=$(slurp -p) || exit 0; }
SHOT=$(mktemp /tmp/oberon-color-XXXXXX.png)

if ! grim -g "$POS" "$SHOT" 2>/dev/null; then
    rm -f "$SHOT"
    notify-send -a Oberon 'Цвет' 'Не удалось снять точку'
    exit 1
fi

HEX=$(magick "$SHOT" -format '%[hex:p{0,0}]' info: 2>/dev/null | head -c 6 | tr 'a-f' 'A-F')
rm -f "$SHOT"

if [ -n "$HEX" ]; then
    printf '%s\n' "#$HEX" | wl-copy
    notify-send -a Oberon 'Цвет' "Скопирован #$HEX" -h "string:bgcolor:#$HEX"
else
    notify-send -a Oberon 'Цвет' 'Не удалось распознать цвет'
fi
