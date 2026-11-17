#!/usr/bin/env bash
# Ночной свет: тёплый фильтр на экране.
#
#   nightlight.sh detect          — какой бэкенд доступен: wlsunset|hyprsunset|none
#   nightlight.sh on [K]          — включить, температура по умолчанию 4000K
#   nightlight.sh off             — выключить
#
# hyprsunset умеет только Hyprland (CTM), поэтому на niri используется
# wlsunset. Выбор не настраивается: он следует за композитором, как яркость
# и остальные вещи, которые зависят от железа и сессии.
set -u

PATH="$PATH:/usr/bin:/usr/local/bin:$HOME/.local/bin:/bin:/opt/bin"
export PATH

STATE="${XDG_RUNTIME_DIR:-/tmp}/panacea-nightlight"
DAY=6500

have() { command -v "$1" >/dev/null 2>&1; }

backend() {
    local d="${XDG_CURRENT_DESKTOP:-}"
    if [ -n "${NIRI_SOCKET:-}" ] || [ "${d,,}" = "niri" ]; then
        have wlsunset && { echo wlsunset; return; }
    fi
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && have hyprctl && have hyprsunset; then
        echo hyprsunset
        return
    fi
    # Без явного композитора берём то, что вообще установлено.
    have wlsunset && { echo wlsunset; return; }
    have hyprctl && have hyprsunset && { echo hyprsunset; return; }
    echo none
}

clamp_temp() {
    local t="${1:-4000}"
    case "$t" in *[!0-9]*) t=4000 ;; esac
    [ "$t" -lt 1000 ] && t=1000
    [ "$t" -gt 6500 ] && t=6500
    echo "$t"
}

case "${1:-}" in
    detect)
        backend
        ;;
    on)
        temp="$(clamp_temp "${2:-4000}")"
        case "$(backend)" in
            wlsunset)
                prev="$(cat "$STATE" 2>/dev/null || true)"
                # Уже горит с этой температурой — не трогаем: перезапуск
                # мигает экраном, а ползунок шлёт значение на каждое движение.
                if pgrep -x wlsunset >/dev/null 2>&1 && [ "$prev" = "$temp" ]; then
                    exit 0
                fi
                pkill -x wlsunset >/dev/null 2>&1 || true
                sleep 0.1
                setsid wlsunset -t "$temp" -T "$DAY" >/dev/null 2>&1 &
                printf '%s\n' "$temp" > "$STATE"
                ;;
            hyprsunset)
                # Автозапуск обычно уже поднял демон; если нет — поднимаем.
                if ! pgrep -x hyprsunset >/dev/null 2>&1; then
                    setsid hyprsunset >/dev/null 2>&1 &
                    sleep 0.4
                fi
                hyprctl hyprsunset temperature "$temp" >/dev/null 2>&1
                printf '%s\n' "$temp" > "$STATE"
                ;;
            none)
                exit 1
                ;;
        esac
        ;;
    off)
        case "$(backend)" in
            wlsunset)
                pkill -x wlsunset >/dev/null 2>&1 || true
                ;;
            hyprsunset)
                # Демон оставляем жить: его же запускает автозапуск, а
                # identity просто снимает тёплый фильтр.
                hyprctl hyprsunset identity >/dev/null 2>&1 || true
                ;;
            none)
                exit 1
                ;;
        esac
        rm -f "$STATE"
        ;;
    *)
        echo "usage: nightlight.sh detect|on <temperature>|off" >&2
        exit 1
        ;;
esac
