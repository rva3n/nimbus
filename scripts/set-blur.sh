#!/bin/sh
# Ползунок «Размытие фона»: 0..100% → радиус размытия Umbriel 2..14.
# Больше 14 на маленькой капсуле бесполезно: фон усредняется в однотонное пятно
# и «блюр» пропадает визуально. 0% — лёгкий мороз, 100% — сильный, но с текстурой.
# Правит `[appearance.blur] radius` в конфиге композитора и перечитывает его.
P=$(printf '%s' "${1:-}" | tr -dc 0-9)
[ -n "$P" ] || exit 1
[ "$P" -gt 100 ] && P=100
R=$(( 3 + P * 13 / 100 ))
CFG=$(grep -rl '^\[appearance\.blur\]' "$HOME/.config/umbriel" 2>/dev/null | head -1)
[ -n "$CFG" ] || exit 1
sed -i -E "/^\[appearance\.blur\]/,/^\[/{s/^radius *=.*/radius = $R/}" "$CFG"
umbriel msg config-reload >/dev/null 2>&1
