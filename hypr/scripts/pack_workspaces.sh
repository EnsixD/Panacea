#!/usr/bin/env bash

# Ottieni la lista dei workspace attivi ordinati per ID (ignorando i workspace speciali come 'magic' che hanno ID negativi o stringhe)
active_workspaces=$(hyprctl workspaces -j | jq -r '[.[] | select(.id > 0)] | sort_by(.id) | .[].id')

# Salva l'ID del workspace attualmente focalizzato per ripristinarlo alla fine
current_ws=$(hyprctl activeworkspace -j | jq -r '.id')
new_ws=$current_ws

target=1

for ws in $active_workspaces; do
    if [ "$ws" -ne "$target" ]; then
        # Ottieni gli indirizzi (address) di tutte le finestre presenti nel workspace che si sta analizzando
        clients=$(hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws | tonumber)) | .address')
        
        # Sposta ogni finestra, in modo silenzioso, verso il workspace di destinazione
        for client in $clients; do
            hyprctl dispatch movetoworkspacesilent "$target,address:$client"
        done
        
        # Se il workspace che stiamo spostando è quello su cui l'utente ha il focus, aggiorna la variabile
        if [ "$ws" -eq "$current_ws" ]; then
            new_ws=$target
        fi
    fi
    ((target++))
done

# Segui lo spostamento portando la visuale sul nuovo workspace dove si trova ora il contenuto che stavi guardando
hyprctl dispatch workspace "$new_ws"
