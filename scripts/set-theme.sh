#!/bin/sh
# Тема из обоев через matugen с нашим конфигом.
# scheme auto: почти бесцветные обои (ч/б, сепия, холодно-серые) →
# scheme-monochrome: строго серая палитра, как в Android, без примеси цвета.
# Цветные обои → scheme-smart: привычный vivid-акцент.
# scheme <name> → фиксированная --type scheme-<name>.
# mode auto → флаг не передаётся (matugen сам выберет по яркости),
# иначе --mode light|dark. contrast ≠ 0 → --contrast <v>.
IMG="${1:?path to image}"
export PATH="$HOME/oberon/build/prefix/bin:$PATH"
CONF="${OBERON_MATUGEN_CONF:-$HOME/oberon/matugen/config.toml}"
FB="#9a9a9a"
PJ="$HOME/oberon/prefs.json"

scheme=$(jq -r '.themeScheme // "auto"' "$PJ" 2>/dev/null)
mode=$(jq -r '.themeMode // "auto"' "$PJ" 2>/dev/null)
contrast=$(jq -r '.themeContrast // 0' "$PJ" 2>/dev/null)
case "$contrast" in ''|*[!0-9.eE+-]*) contrast=0 ;; esac

TYPE=scheme-smart
if [ "$scheme" != "auto" ] && [ -n "$scheme" ]; then
    # фиксированная схема от пользователя (content, fidelity, monochrome,
    # tonalSpot, vibrant, expressive, neutral, ...)
    case "$scheme" in
        tonalSpot)  TYPE=scheme-tonal-spot ;;
        fruitSalad) TYPE=scheme-fruit-salad ;;
        *)          TYPE="scheme-$scheme" ;;
    esac
else
    SRC=$(oberoncolor image -c "$CONF" --prefer saturation --fallback-color "$FB" -j hex --dry-run "$IMG" 2>/dev/null \
          | jq -r '.colors.source_color.default.color // empty' 2>/dev/null)

    if [ "$SRC" = "$FB" ] || [ -z "$SRC" ]; then
        TYPE=scheme-monochrome
    else
        HEX=$(printf '%s' "$SRC" | tr -d '#')
        R=$((16#$(printf '%s' "$HEX" | cut -c1-2)))
        G=$((16#$(printf '%s' "$HEX" | cut -c3-4)))
        B=$((16#$(printf '%s' "$HEX" | cut -c5-6)))
        MAX=$R
        [ "$G" -gt "$MAX" ] && MAX=$G
        [ "$B" -gt "$MAX" ] && MAX=$B
        MIN=$R
        [ "$G" -lt "$MIN" ] && MIN=$G
        [ "$B" -lt "$MIN" ] && MIN=$B
        # почти бесцветный источник (включая серые с лёгким кастом — сепия/синева):
        # строгая монохромная палитра, как в Android на ч/б обоях — без примеси цвета
        [ $((MAX - MIN)) -lt 56 ] && TYPE=scheme-monochrome
    fi
fi

FLAGS="--prefer saturation --type $TYPE --fallback-color $FB"
# mode auto → ничего: без флага matugen сам решает (внутри smart-схемы);
# не-auto → --mode light|dark. (В matugen 4.2 --mode smart тоже есть,
# но auto в префах должен означать «не трогать».)
[ "$mode" = "light" ] || [ "$mode" = "dark" ] && FLAGS="$FLAGS --mode $mode"
# contrast != 0 и число → передать
[ "$(awk "BEGIN{print ($contrast + 0 != 0) ? 1 : 0}" 2>/dev/null)" = "1" ] && FLAGS="$FLAGS --contrast $contrast"

oberoncolor -c "$CONF" $FLAGS image "$IMG" >/dev/null 2>&1
