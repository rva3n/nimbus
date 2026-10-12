#!/bin/sh
# Nimbus: OCR выбранной области → буфер обмена (tesseract -l rus+eng) + тост.
# Запускается из ScreenshotToolbar.qml (окно уже скрыто); slurp выбирает область.
set -u

sleep 0.25
# необязательный аргумент "X,Y WxH" — для ручных тестов; иначе slurp рисует выбор
GEOM="${1:-}"
[ -n "$GEOM" ] || { GEOM=$(slurp) || exit 0; }
SHOT=$(mktemp /tmp/nimbus-ocr-XXXXXX.png)

if ! grim -g "$GEOM" "$SHOT" 2>/dev/null; then
    rm -f "$SHOT"
    notify-send -a Nimbus 'Текст (OCR)' 'Не удалось снять область'
    exit 1
fi

# tesseract любит ~300dpi: узкие кропы перед распознаванием увеличиваем
UP=$(mktemp /tmp/nimbus-ocr-up-XXXXXX.png)
W=$(printf '%s' "$GEOM" | sed -n 's/.* \([0-9]\+\)x\([0-9]\+\)$.*/\1/p')
if [ -n "$W" ] && [ "$W" -lt 1000 ] 2>/dev/null && command -v magick >/dev/null 2>&1; then
    magick "$SHOT" -colorspace gray -resize 300% -sharpen 0x1 -normalize "$UP" 2>/dev/null || cp "$SHOT" "$UP"
else
    cp "$SHOT" "$UP"
fi

TXT=$(tesseract "$UP" - -l rus+eng 2>/dev/null \
    | sed -e 's/[[:space:]]*$//' -e '/./,$!d')
rm -f "$SHOT" "$UP"

if [ -n "$TXT" ]; then
    printf '%s' "$TXT" | wl-copy
    notify-send -a Nimbus 'Текст (OCR)' 'Распознано и скопировано'
else
    notify-send -a Nimbus 'Текст (OCR)' 'Текст не найден'
fi
