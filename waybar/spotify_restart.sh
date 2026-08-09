#!/bin/bash

# Log for debugging
exec > /tmp/spotify_restart.log 2>&1

echo "--- Spotify Restart Started at $(date) ---"

# 1. Kill Spotify
echo "Killing spotify processes..."
pkill -9 -x spotify

# 2. Wait 3 seconds
echo "Waiting 3 seconds..."
sleep 3

# 3. Launch Spotify
echo "Launching Spotify via systemd-run..."
systemd-run --user --unit=spotify-restart-$(date +%s) --description="Spotify from Waybar" spotify --enable-features=UseOzonePlatform --ozone-platform=wayland --force-device-scale-factor=2 > /dev/null 2>&1

# 4. Wait for player and resume playback
echo "Waiting for player..."
sleep 2

for i in {1..30}; do
    if playerctl --player=spotify status > /dev/null 2>&1; then
        echo "Player found at attempt $i. Sending play command..."
        playerctl --player=spotify play 2>/dev/null
        break
    fi
    sleep 0.5
done

echo "--- Script Finished ---"
