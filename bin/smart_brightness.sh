#!/bin/bash
# Яркость ровными шагами, с ускорением при удержании клавиши.
# Логика та же, что у smart_volume.sh: меряем паузу между вызовами,
# при серии подряд идущих нажатий шаг растёт.

MIN=1               # ниже не опускаемся, иначе экран гаснет полностью
MAX=100

STATE="${XDG_RUNTIME_DIR:-/tmp}/panacea-bright.streak"
GAP_MS=280          # пауза больше этой — удержание считается прерванным

now_ms() { date +%s%3N; }

streak=0
if [ -f "$STATE" ]; then
    read -r last prev_streak < "$STATE" 2>/dev/null
    if [ -n "$last" ] && [ $(( $(now_ms) - last )) -lt $GAP_MS ]; then
        streak=$(( prev_streak + 1 ))
    fi
fi
echo "$(now_ms) $streak" > "$STATE"

if   [ "$streak" -lt 4 ];  then STEP=5
elif [ "$streak" -lt 10 ]; then STEP=10
else                            STEP=20
fi

cur_pct() { brightnessctl -m | LC_ALL=C awk -F, '{gsub("%","",$4); print $4}'; }

set_pct() {
    local p=$1
    [ "$p" -lt $MIN ] && p=$MIN
    [ "$p" -gt $MAX ] && p=$MAX
    brightnessctl -q s "${p}%"
}

cur=$(cur_pct)
case "$1" in
    up)   set_pct $(( (cur / STEP) * STEP + STEP )) ;;
    down) set_pct $(( ( (cur + STEP - 1) / STEP ) * STEP - STEP )) ;;
    *)    echo "usage: smart_brightness.sh up|down" >&2; exit 1 ;;
esac

PCT=$(cur_pct)

# Пилюля рисует уровень сама; wob — запасной путь для энергосбережения.
if pgrep -x qs >/dev/null; then
    qs -c "$HOME/.config/panacea" ipc call pill brightness "$PCT" 2>/dev/null &
elif [ -p "$XDG_RUNTIME_DIR/wob.fifo" ] && pgrep -x wob >/dev/null; then
    echo "$PCT" > "$XDG_RUNTIME_DIR/wob.fifo" &
fi
