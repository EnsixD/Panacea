#!/bin/bash
ACTION=$1

case $ACTION in
    up)
        brightnessctl s 5%+
        ;;
    down)
        brightnessctl s 5%-
        ;;
esac

PCT=$(brightnessctl i | grep -oP '\(\K[^%]+')

# Панели сейчас нет. Если запущен wob — рисуем индикатор через него,
# иначе просто ничего не показываем (сама громкость/яркость уже изменена).
if [ -p "$XDG_RUNTIME_DIR/wob.fifo" ] && pgrep -x wob >/dev/null; then
    echo "$PCT" > "$XDG_RUNTIME_DIR/wob.fifo" &
fi
