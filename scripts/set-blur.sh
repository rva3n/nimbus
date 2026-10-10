#!/bin/sh
# Ползунок «Размытие фона»: 0..100% → радиус размытия Umbriel 0..30.
# Радиус — главный рычаг интенсивности: 0% — без блюра, 100% — максимум
# (passes фиксированы = 3). Прозрачность стекла живёт в Theme и почти не
# зависит от ползунка — раньше он в основном крутил альфу и даже отключал
# блюр, когда альфа уходила ниже blur_ignore_alpha.
# Правит `[appearance.blur] radius` в конфиге композитора и перечитывает его.
P=$(printf '%s' "${1:-}" | tr -dc 0-9)
[ -n "$P" ] || exit 1
[ "$P" -gt 100 ] && P=100
R=$(( P * 30 / 100 ))
CFG=$(grep -rl '^\[appearance\.blur\]' "$HOME/.config/umbriel" 2>/dev/null | head -1)
[ -n "$CFG" ] || exit 1
sed -i -E "/^\[appearance\.blur\]/,/^\[/{s/^radius *=.*/radius = $R/}" "$CFG"
umbriel msg config-reload >/dev/null 2>&1
