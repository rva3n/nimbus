#!/bin/sh
# Тема из обоев через matugen с нашим конфигом.
# Если картинка почти без цвета, matugen берёт fallback (по умолчанию у него
# гугло-синий, у нас — серый), а даже серый источник в tonal-spot даёт чуть
# бирюзовый акцент. Поэтому для бесцветных обоев включаем scheme-content —
# он строит честную нейтральную (чёрно-белую) палитру.
IMG="${1:?path to image}"
CONF="${NIMBUS_MATUGEN_CONF:-$HOME/nimbus/matugen/config.toml}"
FB="#9a9a9a"

SRC=$(matugen image -c "$CONF" --prefer saturation --fallback-color "$FB" -j hex --dry-run "$IMG" 2>/dev/null \
      | jq -r '.colors.source_color.default.color // empty' 2>/dev/null)

TYPE=scheme-tonal-spot
[ "$SRC" = "$FB" ] && TYPE=scheme-content

matugen -c "$CONF" --prefer saturation --type "$TYPE" --fallback-color "$FB" image "$IMG" >/dev/null 2>&1
