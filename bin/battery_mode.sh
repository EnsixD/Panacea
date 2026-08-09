#!/bin/bash

# Percorsi
CONFIG="$HOME/.config/hypr/modules/look_and_feel.conf"
START="### BEST BATTERY LIFE ###"
END="### MONITORS ###"

# Dati del monitor (Dinamici)
MONITOR_INFO=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
MONITOR=$(echo "$MONITOR_INFO" | jq -r '.name')
WIDTH=$(echo "$MONITOR_INFO" | jq -r '.width')
HEIGHT=$(echo "$MONITOR_INFO" | jq -r '.height')
RES="${WIDTH}x${HEIGHT}"
POS="$(echo "$MONITOR_INFO" | jq -r '.x')x$(echo "$MONITOR_INFO" | jq -r '.y')"
SCALE=$(echo "$MONITOR_INFO" | jq -r '.scale')

# Funzione per attivare il Risparmio (120Hz + VRR + No Eye Candy)
# Manteniamo 120Hz perché permette al driver di allineare meglio i frame (48Hz floor)
enable_battery() {
    echo "Enabling Battery Savings (120Hz VRR + No Effects)..."
    sed -i "/$START/,/$END/ { /$START/! { /$END/! s/^#[[:space:]]*// } }" "$CONFIG"
    hyprctl keyword monitor "$MONITOR,$RES@120,$POS,$SCALE,vrr,1"
    /home/ensi/.config/hypr/scripts/switch_theme.sh black
    sleep 0.5
    
    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } } })'
    
    # Tide Island управляется systemd — останавливаем службу, а не процесс,
    # иначе Restart=on-failure поднимет её обратно
    if systemctl --user is-active --quiet tide-island.service; then
        systemctl --user stop tide-island.service
    else
        pkill -x qs; pkill -x quickshell
    fi
    waybar &
    
    # Start wob for OSD
    rm -f $XDG_RUNTIME_DIR/wob.fifo && mkfifo $XDG_RUNTIME_DIR/wob.fifo
    tail -f $XDG_RUNTIME_DIR/wob.fifo | wob -c ~/.config/wob/wob.ini &
}

disable_battery() {
    echo "Restoring Performance Mode (120Hz VRR + Animations)..."
    sed -i "/$START/,/$END/ { /$START/! { /$END/! { /^[[:space:]]*#/! s/^/#/ } } }" "$CONFIG"
    hyprctl keyword monitor "$MONITOR,$RES@120,$POS,$SCALE,vrr,1"
    
    /home/ensi/.config/hypr/scripts/switch_theme.sh minimal
    sleep 0.5
    
    hyprctl eval '
    local theme = require("theme")
    hl.config({
        animations = { enabled = true },
        decoration = {
            rounding = theme.rounding,
            shadow = { enabled = theme.shadow_enabled },
            blur = { enabled = theme.blur_enabled }
        }
    })
    ' >> /tmp/battery_mode.log 2>&1
    
    pkill waybar
    pkill wob
    # возвращаем панель: Tide через systemd, иначе прежнюю оболочку
    if [ -x "$HOME/.local/bin/tide-island" ]; then
        systemctl --user start tide-island.service
    else
        qs -c "$HOME/.config/panacea" &
    fi
}

# LOGICA DI TOGGLE
echo "Running toggle check..." >> /tmp/battery_mode.log
if sed -n "/$START/,/$END/p" "$CONFIG" | grep -q "^#animations"; then
    echo "Enabling battery" >> /tmp/battery_mode.log
    enable_battery >> /tmp/battery_mode.log 2>&1
else
    echo "Disabling battery" >> /tmp/battery_mode.log
    disable_battery >> /tmp/battery_mode.log 2>&1
fi

# Notifica Quickshell per aggiornare l'interfaccia
# старой оболочке нужно было сообщить о смене режима; Tide следит сам
qs -c "$HOME/.config/panacea" ipc call pill close 2>/dev/null || true
