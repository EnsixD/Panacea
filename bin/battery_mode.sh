#!/bin/bash
#
# Режим энергосбережения: гасит анимации, тени и размытие, убирает пилюлю и
# ставит вместо неё waybar с wob. Второй запуск возвращает всё обратно.
#
# Оболочку поднимает Hyprland (exec-once в programs.lua), службы у неё нет —
# поэтому останавливаем и запускаем сам процесс.

# Включён режим или нет, помнит этот файл. Раньше признаком служила
# закомментированная секция в hypr/modules/look_and_feel.conf — но конфиг
# Hyprland давно лежит в lua/, а .conf никто не читает, так что скрипт
# комментировал строки, которые ни на что не влияли, и хранил в них флаг.
# В runtime-каталоге ему не место: режим должен пережить перезагрузку.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/panacea"
STATE="$STATE_DIR/battery-mode"
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
    mkdir -p "$STATE_DIR" && : > "$STATE"
    hyprctl keyword monitor "$MONITOR,$RES@120,$POS,$SCALE,vrr,1"
    "$HOME/.config/hypr/scripts/switch_theme.sh" black
    sleep 0.5

    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } } })'

    pkill -x qs; pkill -x quickshell
    # на случай, если режим включают повторно: без этого рядом встал бы
    # второй waybar, а первый остался бы висеть
    pkill waybar
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
    rm -f "$STATE"
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
    if [ -e "$STATE" ]; then
        echo "Disabling battery"
        disable_battery
    else
        echo "Enabling battery"
        enable_battery
    fi
} >> "$LOG" 2>&1
