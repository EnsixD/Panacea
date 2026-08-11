#!/bin/bash
# Экраны: список мониторов и перезапись ~/.config/hypr/monitors.conf.
#
#   list             -> JSON от hyprctl, включая выключенные мониторы и все
#                       доступные режимы каждого
#   apply "<строки>"  -> кладёт готовые строки monitor=… в monitors.conf
#                       и просит Hyprland перечитать конфиг
#   reset            -> возвращает автоматическую раскладку
#
# Строки собирает панель настроек: она знает и режимы, и выбранную раскладку,
# а скрипту остаётся только запись и reload. Через файл, а не hyprctl keyword,
# потому что иначе настройка терялась при следующем reload.

OUT="$HOME/.config/hypr/monitors.conf"

HEAD="# Файл создаётся автоматически панелью настроек пилюли (Super+I → Экран).
# Правки руками будут затёрты при следующем «Применить»."

# Последняя строка — для мониторов, которых панель не знает: они включатся
# сами, а не останутся чёрными до захода в настройки.
TAIL="monitor=,preferred,auto,1.0"

case "$1" in
list)
    hyprctl -j monitors all
    ;;

apply)
    [ -n "$2" ] || exit 1
    mkdir -p "$(dirname "$OUT")"
    printf '%s\n%s\n%s\n' "$HEAD" "$2" "$TAIL" > "$OUT" || exit 1
    hyprctl reload >/dev/null 2>&1
    ;;

reset)
    mkdir -p "$(dirname "$OUT")"
    printf '%s\n%s\n' "$HEAD" "$TAIL" > "$OUT" || exit 1
    hyprctl reload >/dev/null 2>&1
    ;;

*)
    echo "usage: monitors.sh list|apply <lines>|reset" >&2
    exit 2
    ;;
esac
