#!/bin/bash
# Громкость ровными шагами, с ускорением при удержании клавиши.
#
# Базовый шаг 5%. Hyprland при зажатой клавише вызывает скрипт снова и снова,
# поэтому меряем паузу между вызовами: если они идут подряд, шаг растёт.
#
# wpctl умеет относительные шаги (5%+), но если текущее значение не кратно
# пяти, оно таким и останется: 43 -> 48 -> 53. Поэтому считаем сами:
# округляем текущий уровень до кратного шагу и уже от него шагаем.

SINK="@DEFAULT_AUDIO_SINK@"
MAX=100

STATE="${XDG_RUNTIME_DIR:-/tmp}/panacea-vol.streak"
GAP_MS=280          # паузa больше этой — удержание считается прерванным

now_ms() { date +%s%3N; }

# --- определяем длину серии подряд идущих нажатий
streak=0
if [ -f "$STATE" ]; then
    read -r last prev_streak < "$STATE" 2>/dev/null
    if [ -n "$last" ] && [ $(( $(now_ms) - last )) -lt $GAP_MS ]; then
        streak=$(( prev_streak + 1 ))
    fi
fi
echo "$(now_ms) $streak" > "$STATE"

# --- шаг растёт по мере удержания
if   [ "$streak" -lt 4 ];  then STEP=5
elif [ "$streak" -lt 10 ]; then STEP=10
else                            STEP=20
fi

cur_pct() {
    # "Volume: 0.45" либо "Volume: 0.45 [MUTED]"
    wpctl get-volume "$SINK" | LC_ALL=C awk '{printf "%d", $2 * 100 + 0.5}'
}

set_pct() {
    local p=$1
    [ "$p" -lt 0 ]    && p=0
    [ "$p" -gt $MAX ] && p=$MAX
    wpctl set-volume "$SINK" "${p}%"
}

case "$1" in
    up)
        cur=$(cur_pct)
        set_pct $(( (cur / STEP) * STEP + STEP ))
        # прибавление громкости снимает немоту — иначе непонятно, почему тихо
        wpctl set-mute "$SINK" 0
        ;;
    down)
        cur=$(cur_pct)
        set_pct $(( ( (cur + STEP - 1) / STEP ) * STEP - STEP ))
        ;;
    mute)
        wpctl set-mute "$SINK" toggle
        ;;
    *)
        echo "usage: smart_volume.sh up|down|mute" >&2
        exit 1
        ;;
esac

# Уровень показывает сама пилюля: она следит за Pipewire и рисует полоску.
# wob остаётся запасным вариантом на случай режима энергосбережения.
if ! pgrep -x qs >/dev/null; then
    VAL=$(wpctl get-volume "$SINK")
    if echo "$VAL" | grep -q "MUTED"; then PCT=0; else PCT=$(cur_pct); fi
    if [ -p "$XDG_RUNTIME_DIR/wob.fifo" ] && pgrep -x wob >/dev/null; then
        echo "$PCT" > "$XDG_RUNTIME_DIR/wob.fifo" &
    fi
fi
