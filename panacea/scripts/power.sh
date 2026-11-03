#!/bin/bash
# Профили питания через D-Bus API net.hadess.PowerProfiles.
# Его отдаёт tlp-pd (TLP, ставится на Arch) или power-profiles-daemon.
#
#   get          -> power-saver | balanced | performance
#   set PROFILE  -> переключить профиль
#
# Штатный powerprofilesctl в этой системе не работает: ему нужен
# python-gobject, которого может не быть. Демон при этом активен, поэтому
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
        case "${2:-}" in power-saver|balanced|performance) ;; *) exit 1 ;; esac
        busctl --system set-property "$BUS" "$OBJ" "$BUS" ActiveProfile s "$2" || exit 1
        # tlp-pd applies profiles asynchronously; an immediate read can be stale.
        for ((i=0; i<50; i++)); do
            active=$(busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null | sed 's/^s //; s/"//g')
            [ "$active" = "$2" ] && exit 0
            sleep 0.1
        done
        echo "Power profile did not change to $2" >&2
        exit 1
        ;;
    *)
        echo "usage: power.sh get | set <power-saver|balanced|performance>" >&2
        exit 1
        ;;
esac
