#!/bin/sh
# Настройки питания Oberon: минуты бездействия до гашения экрана (DPMS),
# блокировки и сна; 0 = никогда. Переписывает hypridle.conf Umbriel
# и перезапускает hypridle (живого релоада у него нет).
S=$(printf '%s' "${1:-}" | tr -dc 0-9); [ -n "$S" ] || S=10
L=$(printf '%s' "${2:-}" | tr -dc 0-9); [ -n "$L" ] || L=0
U=$(printf '%s' "${3:-}" | tr -dc 0-9); [ -n "$U" ] || U=60
CONF="$HOME/.config/umbriel/hypridle.conf"

{
    echo "# Сгенерировано Oberon (Настройки → Питание); ручные правки будут перезаписаны."
    echo '$suspend_cmd = systemctl suspend || loginctl suspend'
    echo 'general {'
    echo '    before_sleep_cmd = $suspend_cmd'
    echo '    inhibit_sleep = 3'
    echo '}'
    if [ "$S" -gt 0 ]; then
        echo 'listener { # гашение экрана'
        echo "    timeout = $((S * 60))"
        echo '    on-timeout = umbriel msg dpms-off'
        echo '    on-resume = umbriel msg dpms-on'
        echo '}'
    fi
    if [ "$L" -gt 0 ]; then
        echo 'listener { # блокировка'
        echo "    timeout = $((L * 60))"
        echo "    on-timeout = /usr/bin/qs -p $HOME/oberon ipc call oberon lock"
        echo '}'
    fi
    if [ "$U" -gt 0 ]; then
        echo 'listener { # сон'
        echo "    timeout = $((U * 60))"
        echo '    on-timeout = $suspend_cmd'
        echo '}'
    fi
} > "$CONF"

pkill -x hypridle 2>/dev/null
sleep 0.3
setsid -f hypridle -c "$CONF" >/dev/null 2>&1
umbriel msg dpms-on >/dev/null 2>&1
