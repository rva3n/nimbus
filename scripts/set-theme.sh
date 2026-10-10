#!/bin/sh
# Тема из обоев через matugen с нашим конфигом.
# Почти бесцветные обои (ч/б, сепия, холодно-серые) → scheme-monochrome:
# строго серая палитра, как в Android, без примеси цвета в контейнерах.
# Цветные обои → scheme-smart: привычный vivid-акцент.
IMG="${1:?path to image}"
CONF="${NIMBUS_MATUGEN_CONF:-$HOME/nimbus/matugen/config.toml}"
FB="#9a9a9a"

SRC=$(matugen image -c "$CONF" --prefer saturation --fallback-color "$FB" -j hex --dry-run "$IMG" 2>/dev/null \
      | jq -r '.colors.source_color.default.color // empty' 2>/dev/null)

TYPE=scheme-smart
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

matugen -c "$CONF" --prefer saturation --type "$TYPE" --fallback-color "$FB" image "$IMG" >/dev/null 2>&1
