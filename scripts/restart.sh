#!/bin/sh
# restart.sh — перезапуск шелла Oberon (кнопка «Перезапустить» в панели,
# а также `update.sh --restart`).
set -eu

QS="$HOME/oberon/build/prefix/bin/oberonqs"
IDLE="$HOME/oberon/build/prefix/bin/oberonidle"
IDLE_CONF="$HOME/.config/umbriel/oberonidle.conf"

sleep 0.4
pkill -x oberonqs 2>/dev/null || true
sleep 0.6
setsid "$QS" -p "$HOME/oberon" >/dev/null 2>&1 &

# oberonidle тоже обновляется сборкой — перезапускаем, если он был запущен
if pgrep -x oberonidle >/dev/null; then
	pkill -x oberonidle 2>/dev/null || true
	setsid "$IDLE" -c "$IDLE_CONF" >/dev/null 2>&1 &
fi
