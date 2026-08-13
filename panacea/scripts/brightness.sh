#!/usr/bin/env bash
# Яркость — один вход для всех машин.
#
#   brightness.sh detect          — что за машина и чем тут крутить яркость
#   brightness.sh list            — управляемые экраны: id, имя, проценты
#   brightness.sh get <id>        — проценты одного экрана
#   brightness.sh set <id> <pct>  — выставить проценты
#   brightness.sh up|down         — шаг с ускорением при удержании клавиши
#
# Ноутбук и ПК различаются не настройкой, а железом, и спрашивать об этом
# человека незачем:
#
#   * есть /sys/class/backlight/* — внутренняя матрица, крутим brightnessctl;
#   * иначе внешний монитор, и остаётся DDC/CI поверх I2C — ddcutil.
#
# У DDC свои правила: шина отвечает медленно (десятки миллисекунд на запрос),
# отвечает не всегда, а `ddcutil detect` со всеми проверками занимает секунды.
# Поэтому карта «шина → разъём» считается один раз и живёт в кэше, а запросы
# всегда идут с явным --bus: без него ddcutil сам ищет монитор заново.
set -u

RUN="${XDG_RUNTIME_DIR:-/tmp}"
CACHE="$RUN/panacea-brightness.map"
STATE="$RUN/panacea-bright.streak"

MIN=1               # ниже не опускаемся, иначе экран гаснет полностью
MAX=100

have() { command -v "$1" >/dev/null 2>&1; }

# --------------------------------------------------------------- что за машина
# Батарея — единственный честный признак ноутбука: корпус в DMI на сборных
# машинах врёт, а вот battery в power_supply просто так не появляется.
has_battery() {
    local d
    for d in /sys/class/power_supply/*; do
        [ -r "$d/type" ] || continue
        [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] && return 0
    done
    return 1
}

has_touchpad() {
    have hyprctl || return 1
    hyprctl -j devices 2>/dev/null | grep -qiE '"name": *"[^"]*(touchpad|synaptics|trackpad)' && return 0
    grep -qiE 'touchpad|synaptics' /proc/bus/input/devices 2>/dev/null
}

# Внутренняя матрица. У светодиодов клавиатуры свой класс (leds), в backlight
# они не попадают — поэтому именно этот каталог, а не вывод brightnessctl без
# аргументов: тот показывает первое попавшееся устройство, включая подсветку
# клавиш, и на ПК врал бы про наличие управления яркостью.
backlight_dev() {
    local d
    for d in /sys/class/backlight/*; do
        [ -d "$d" ] || continue
        basename "$d"; return 0
    done
    return 1
}

backend() {
    backlight_dev >/dev/null 2>&1 && { echo backlight; return; }
    have ddcutil && [ -e /dev/i2c-0 ] && { echo ddc; return; }
    echo none
}

cmd_detect() {
    local b; b="$(backend)"
    echo "backend=$b"
    if has_battery; then echo "battery=1"; echo "chassis=laptop"
    else echo "battery=0"; echo "chassis=desktop"; fi
    has_touchpad && echo "touchpad=1" || echo "touchpad=0"
    have ddcutil && echo "ddcutil=1" || echo "ddcutil=0"
}

# ------------------------------------------------------------------- backlight
bl_get() { brightnessctl -d "$1" -m 2>/dev/null | LC_ALL=C awk -F, '{gsub("%","",$4); print $4}'; }
bl_set() { brightnessctl -d "$1" -q s "$2%" 2>/dev/null; }

# ------------------------------------------------------------------------- DDC
# Карта шин. Строки «шина<TAB>разъём»; разъём — то же имя, каким монитор
# зовётся в Hyprland (HDMI-A-1, DP-2), чтобы вкладка Display могла свести
# ползунок с нужной карточкой.
ddc_scan() {
    local bus="" conn=""
    ddcutil detect --brief 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            *"I2C bus:"*)       bus="${line##*/dev/i2c-}" ;;
            *"DRM connector:"*)
                conn="${line##*: }"
                conn="$(echo "$conn" | tr -d ' \t')"
                # card1-HDMI-A-1 → HDMI-A-1
                conn="${conn#card*-}"
                [ -n "$bus" ] && [ -n "$conn" ] && printf '%s\t%s\n' "$bus" "$conn"
                bus=""; conn=""
                ;;
        esac
    done
}

ddc_map() {
    # Кэш живёт до перезагрузки или до пересканирования: мониторы не
    # переезжают между шинами сами по себе, а платить секундами за каждый
    # показ настроек нельзя.
    [ -s "$CACHE" ] || ddc_scan > "$CACHE" 2>/dev/null
    cat "$CACHE" 2>/dev/null
}

ddc_get() { ddcutil --bus "$1" getvcp 10 --brief 2>/dev/null | LC_ALL=C awk '{print $4}'; }
ddc_set() { ddcutil --bus "$1" setvcp 10 "$2" >/dev/null 2>&1; }

# ---------------------------------------------------------------------- общие
clamp() {
    local p="$1"
    [ "$p" -lt "$MIN" ] && p="$MIN"
    [ "$p" -gt "$MAX" ] && p="$MAX"
    echo "$p"
}

cmd_list() {
    case "$(backend)" in
        backlight)
            local d; d="$(backlight_dev)" || return 0
            printf 'bl:%s\t%s\t%s\n' "$d" "$(tr -d '\n' <<<"${DISPLAY_LABEL:-Встроенный экран}")" "$(bl_get "$d")"
            ;;
        ddc)
            local bus conn pct
            while IFS=$'\t' read -r bus conn; do
                [ -n "$bus" ] || continue
                pct="$(ddc_get "$bus")"
                # Монитор может быть виден на шине, но не отвечать на VCP 0x10
                # (дешёвые панели и почти все ноутбучные док-станции). Такой
                # экран в список не попадает — ползунок без обратной связи
                # хуже, чем его отсутствие.
                [ -n "$pct" ] || continue
                printf 'ddc:%s\t%s\t%s\n' "$bus" "$conn" "$pct"
            done < <(ddc_map)
            ;;
    esac
}

cmd_get() {
    case "$1" in
        bl:*)  bl_get "${1#bl:}" ;;
        ddc:*) ddc_get "${1#ddc:}" ;;
    esac
}

cmd_set() {
    local id="$1" pct; pct="$(clamp "$2")"
    case "$id" in
        bl:*)  bl_set "${id#bl:}" "$pct" ;;
        ddc:*) ddc_set "${id#ddc:}" "$pct" ;;
    esac
    echo "$pct"
}

# Первый управляемый экран: клавишам яркости выбирать не из чего.
first_id() { cmd_list | head -1 | cut -f1; }

# Шаг с ускорением: меряем паузу между вызовами, при серии подряд идущих
# нажатий шаг растёт. Логика та же, что у smart_volume.sh.
step_now() {
    local now streak=0 last prev
    now="$(date +%s%3N)"
    if [ -f "$STATE" ]; then
        read -r last prev < "$STATE" 2>/dev/null
        if [ -n "${last:-}" ] && [ $(( now - last )) -lt 280 ]; then
            streak=$(( ${prev:-0} + 1 ))
        fi
    fi
    echo "$now $streak" > "$STATE"
    if   [ "$streak" -lt 4 ];  then echo 5
    elif [ "$streak" -lt 10 ]; then echo 10
    else                            echo 20
    fi
}

cmd_step() {
    local dir="$1" id cur step pct
    id="$(first_id)"; [ -n "$id" ] || exit 1
    cur="$(cmd_get "$id")"; [ -n "$cur" ] || exit 1
    step="$(step_now)"
    if [ "$dir" = up ]; then
        pct=$(( (cur / step) * step + step ))
    else
        pct=$(( ( (cur + step - 1) / step ) * step - step ))
    fi
    pct="$(cmd_set "$id" "$pct")"

    # Уровень рисует пилюля: яркость идёт мимо Pipewire, и сама она об
    # изменении не узнает — поэтому говорим ей об этом.
    if pgrep -x qs >/dev/null 2>&1; then
        qs -c "$HOME/.config/panacea" ipc call pill brightness "$pct" 2>/dev/null &
    fi
}

case "${1:-}" in
    detect)  cmd_detect ;;
    list)    cmd_list ;;
    rescan)  rm -f "$CACHE"; ddc_map >/dev/null; cmd_list ;;
    get)     cmd_get "${2:-}" ;;
    set)     cmd_set "${2:-}" "${3:-0}" ;;
    up)      cmd_step up ;;
    down)    cmd_step down ;;
    *)       echo "usage: brightness.sh detect|list|rescan|get <id>|set <id> <pct>|up|down" >&2; exit 1 ;;
esac
