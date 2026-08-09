#!/bin/bash
ACTION=$1

case $ACTION in
    up)
        wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
esac

VAL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
if echo "$VAL" | grep -q "MUTED"; then
    PCT=0
else
    PCT=$(echo "$VAL" | LC_ALL=C awk '{print int($2 * 100)}')
fi

# Панели сейчас нет. Если запущен wob — рисуем индикатор через него,
# иначе просто ничего не показываем (сама громкость/яркость уже изменена).
if [ -p "$XDG_RUNTIME_DIR/wob.fifo" ] && pgrep -x wob >/dev/null; then
    echo "$PCT" > "$XDG_RUNTIME_DIR/wob.fifo" &
fi
