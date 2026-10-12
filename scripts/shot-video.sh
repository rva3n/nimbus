#!/bin/sh
# Nimbus: toggle-запись экрана через wf-recorder; pid-файл в /tmp/nimbus-
# recorder.pid. Старт: уведомление и фоновый процесс, файл ~/Videos/ААА.mp4.
# Стоп: SIGINT wf-recorder (корректно закрывает контейнер), уведомление.
set -u

PIDFILE=/tmp/nimbus-recorder.pid

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    PID=$(cat "$PIDFILE")
    kill -INT "$PID" 2>/dev/null
    # wf-recorder на прерывание дописывает контейнер — даём уложиться
    i=0
    while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 20 ]; do sleep 0.25; i=$((i+1)); done
    rm -f "$PIDFILE"
    notify-send -a Nimbus 'Запись экрана' 'Запись остановлена, файл сохранён'
    exit 0
fi

mkdir -p "$HOME/Videos"
OUT="$HOME/Videos/$(date +%F_%H-%M-%S).mp4"

nohup wf-recorder --pixel-format yuv420p -f "$OUT" >/dev/null 2>&1 &
echo $! > "$PIDFILE"

# pid-файл мог не появиться, если wf-recorder упал сразу (нет записи? нет выхода)
sleep 0.3
if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    rm -f "$PIDFILE"
    notify-send -a Nimbus 'Запись экрана' 'Не удалось начать запись'
    exit 1
fi

notify-send -a Nimbus 'Запись экрана' "Запись началась: $OUT"
