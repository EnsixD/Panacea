#!/bin/bash
# Запуск экрана блокировки (lock.qml).
#
# Здесь же готовится фон: обои темы, ужатые под экран и закешированные.
# Сам QML читает путь из PANACEA_LOCK_BG.

DIR="$(dirname "$(readlink -f "$0")")"
QML="$DIR/../lock.qml"

# уже заблокировано — второй экземпляр не нужен
pgrep -f "quickshell --path .*lock\.qml" >/dev/null && exit 0

wallpaper=$(grep -m1 '^\$wallpaper' "$HOME/.config/hypr/wallpaper.conf" 2>/dev/null \
            | cut -d= -f2- | sed 's/^ *//; s/ *$//')
wallpaper="${wallpaper/#\~/$HOME}"

if [ -n "$wallpaper" ] && [ "$wallpaper" != "black" ] && [ -f "$wallpaper" ]; then
    bg=$("$DIR/thumbs.sh" lockbg "$wallpaper" 2>/dev/null)
    [ -n "$bg" ] && export PANACEA_LOCK_BG="$bg"
fi

exec quickshell --path "$QML"
