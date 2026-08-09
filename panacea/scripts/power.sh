#!/bin/bash
# Профили питания через power-profiles-daemon.
#
#   get          -> power-saver | balanced | performance
#   set PROFILE  -> переключить профиль
#
# Штатный powerprofilesctl в этой системе не работает: ему нужен
# python-gobject, которого нет. Демон при этом активен, поэтому
# разговариваем с ним напрямую по D-Bus через busctl (входит в systemd).
# Переключение разрешено пользователю активной сессии, sudo не нужно.

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"

case "$1" in
    get)
        busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null \
            | sed 's/^s //; s/"//g'
        ;;
    set)
        [ -z "$2" ] && exit 1
        busctl --system set-property "$BUS" "$OBJ" "$BUS" ActiveProfile s "$2" 2>/dev/null
        ;;
    *)
        echo "usage: power.sh get | set <power-saver|balanced|performance>" >&2
        exit 1
        ;;
esac
