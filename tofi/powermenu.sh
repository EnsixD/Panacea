#!/usr/bin/env bash
options="Shutdown\nLock\nReboot\nSuspend\nLogout"

# DEVE usare solo il config, senza aggiungere colori a mano qui!
choice=$(echo -e "$options" | tofi --config ~/.config/tofi/configpowermenu)

case "$choice" in
    "Shutdown") systemctl poweroff ;;
    "Lock") hyprlock ;;
    "Reboot") systemctl reboot ;;
    "Suspend") hyprlock & sleep 1 && systemctl suspend ;;
    "Logout") hyprctl dispatch "hl.dsp.exit()" ;;
esac