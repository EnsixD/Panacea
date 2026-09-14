#!/usr/bin/env bash
# Установка обоев рабочего стола под композитором Niri для Panacea.

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
PANACEA_CFG="$CONF/panacea/settings.json"
HYPR_WALL="$CONF/hypr/wallpaper.conf"
DEFAULT_WALL="$CONF/hypr/wallpaper/ember_stripes.jpg"

WALL=""

# 1. Проверяем wallpaper.conf (содержит путь к файлу)
if [ -f "$HYPR_WALL" ]; then
    CANDIDATE="$(grep -E '^preload|^wallpaper' "$HYPR_WALL" 2>/dev/null | head -1 | sed -n 's/.*= *//p' | tr -d '\r\n')"
    [ -f "$CANDIDATE" ] && WALL="$CANDIDATE"
fi

# 2. Если не найден, проверяем settings.json
if [ -z "$WALL" ] && [ -f "$PANACEA_CFG" ] && command -v jq >/dev/null 2>&1; then
    WNAME="$(jq -r '.wallpaper // empty' "$PANACEA_CFG" 2>/dev/null)"
    if [ -n "$WNAME" ] && [ -f "$CONF/hypr/wallpaper/$WNAME" ]; then
        WALL="$CONF/hypr/wallpaper/$WNAME"
    elif [ -n "$WNAME" ] && [ -f "$WNAME" ]; then
        WALL="$WNAME"
    fi
fi

# 3. Резервный вариант
if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    WALL="$DEFAULT_WALL"
fi

[ -f "$WALL" ] || exit 0

# Установка обоев в зависимости от доступной утилиты
if command -v swaybg >/dev/null 2>&1; then
    pkill -x swaybg >/dev/null 2>&1
    exec swaybg -m fill -i "$WALL" >/dev/null 2>&1 &
elif command -v hyprpaper >/dev/null 2>&1; then
    pkill -x hyprpaper >/dev/null 2>&1
    TMP_CONF="$(mktemp --suffix=.conf)"
    printf 'preload = %s\nwallpaper = ,%s\n' "$WALL" "$WALL" > "$TMP_CONF"
    hyprpaper -c "$TMP_CONF" >/dev/null 2>&1 &
    (sleep 2 && rm -f "$TMP_CONF") &
fi
