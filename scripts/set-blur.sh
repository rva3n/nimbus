#!/bin/sh
# Интенсивность размытия Umbriel: правит `[appearance.blur] radius` в конфиге
# композитора и перечитывает его. Аргумент — радиус 0..100 (общий для панелей
# и окон: другого уровня управления у композитора нет).
R=$(printf '%s' "${1:-}" | tr -dc 0-9)
[ -n "$R" ] || exit 1
[ "$R" -gt 100 ] && R=100
CFG=$(grep -rl '^\[appearance\.blur\]' "$HOME/.config/umbriel" 2>/dev/null | head -1)
[ -n "$CFG" ] || exit 1
sed -i -E "/^\[appearance\.blur\]/,/^\[/{s/^radius *=.*/radius = $R/}" "$CFG"
umbriel msg config-reload >/dev/null 2>&1
