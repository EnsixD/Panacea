#!/bin/bash
#
# Режим энергосбережения: гасит анимации, тени и размытие, убирает пилюлю и
# ставит вместо неё waybar с wob. Второй запуск возвращает всё обратно.
#
# Оболочку поднимает Hyprland (exec-once в programs.lua), службы у неё нет —
# поэтому останавливаем и запускаем сам процесс.

CONFIG="$HOME/.config/hypr/modules/look_and_feel.conf"
START="### BEST BATTERY LIFE ###"
END="### MONITORS ###"
LOG="${XDG_RUNTIME_DIR:-/tmp}/battery_mode.log"
SHELL_CMD="qs -c $HOME/.config/panacea"
FIFO="${XDG_RUNTIME_DIR:-/tmp}/wob.fifo"

# Текущий монитор: режим переставляет его на 120 Гц с VRR. Частоту не
# опускаем — при VRR драйвер сам роняет её до 48 Гц на статичной картинке,
# и фиксированные 60 дали бы меньше выигрыша, чем плавающие 120.
MONITOR_INFO=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
MONITOR=$(echo "$MONITOR_INFO" | jq -r '.name')
WIDTH=$(echo "$MONITOR_INFO" | jq -r '.width')
HEIGHT=$(echo "$MONITOR_INFO" | jq -r '.height')
RES="${WIDTH}x${HEIGHT}"
POS="$(echo "$MONITOR_INFO" | jq -r '.x')x$(echo "$MONITOR_INFO" | jq -r '.y')"
SCALE=$(echo "$MONITOR_INFO" | jq -r '.scale')

enable_battery() {
    echo "Enabling Battery Savings (120Hz VRR + No Effects)..."
    sed -i "/$START/,/$END/ { /$START/! { /$END/! s/^#[[:space:]]*// } }" "$CONFIG"
    hyprctl keyword monitor "$MONITOR,$RES@120,$POS,$SCALE,vrr,1"
    "$HOME/.config/hypr/scripts/switch_theme.sh" black
    sleep 0.5

    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } } })'

    pkill -x qs; pkill -x quickshell
    waybar &

    # Уровень громкости и яркости: пилюля погашена, показывает wob.
    # Сначала снимаем прошлого читателя — иначе он остаётся висеть на старом
    # inode трубы, и с каждым включением режима их копится всё больше.
    pkill -f "tail -f $FIFO"
    rm -f "$FIFO" && mkfifo "$FIFO"
    tail -f "$FIFO" | wob -c "$HOME/.config/wob/wob.ini" &
}

disable_battery() {
    echo "Restoring Performance Mode (120Hz VRR + Animations)..."
    sed -i "/$START/,/$END/ { /$START/! { /$END/! { /^[[:space:]]*#/! s/^/#/ } } }" "$CONFIG"
    hyprctl keyword monitor "$MONITOR,$RES@120,$POS,$SCALE,vrr,1"

    "$HOME/.config/hypr/scripts/switch_theme.sh" minimal
    sleep 0.5

    hyprctl eval '
    local theme = require("theme")
    hl.config({
        animations = { enabled = true },
        decoration = {
            rounding = theme.rounding,
            shadow = { enabled = theme.shadow_enabled },
            blur = { enabled = theme.blur_enabled }
        }
    })
    '

    pkill waybar
    pkill wob
    pkill -f "tail -f $FIFO"

    $SHELL_CMD &
}

{
    echo "Running toggle check..."
    if sed -n "/$START/,/$END/p" "$CONFIG" | grep -q "^#animations"; then
        echo "Enabling battery"
        enable_battery
    else
        echo "Disabling battery"
        disable_battery
    fi
} >> "$LOG" 2>&1
