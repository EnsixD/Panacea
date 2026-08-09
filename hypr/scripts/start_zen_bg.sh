#!/bin/bash

# Wait for Hyprland/Wayland to fully initialize during boot
sleep 2

# Apply a temporary, dynamic window rule to force all Zen windows to the special workspace silently
hyprctl keyword windowrule "match:class zen, workspace special:zenbg silent"

# Start Zen Browser in the background
zen-browser &

# Wait for the browser to fully launch and map its initial windows
sleep 5

# Clear the temporary rule so that new windows (SUPER+W) open normally on the active workspace
hyprctl reload

