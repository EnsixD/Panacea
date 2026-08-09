#!/bin/bash

notify-send "Wi-Fi" "Scanning for networks..." -t 2000

# Get list of networks (SSID and Security)
# We sort them by signal strength implicitly (nmcli does this) and remove duplicates
networks=$(nmcli --get-values IN-USE,SSID dev wifi list | awk -F':' '{if($2!="" && !seen[$2]++) { if($1=="*") print $2" (connected)"; else print $2 } }')

if [ -z "$networks" ]; then
    notify-send "Wi-Fi" "No networks found or Wi-Fi is disabled."
    exit 1
fi

# Show menu
chosen=$(echo "$networks" | tofi --prompt-text "Wi-Fi: ")

if [ -z "$chosen" ]; then
    exit 0
fi

# Strip " (connected)" if present
chosen_network="${chosen% (connected)}"


# Check if it's a known connection
known=$(nmcli connection show | grep -w "$chosen_network")

if [ -n "$known" ]; then
    notify-send "Wi-Fi" "Connecting to $chosen_network..."
    if nmcli connection up id "$chosen_network"; then
        notify-send "Wi-Fi" "Successfully connected to $chosen_network."
    else
        notify-send "Wi-Fi" "Failed to connect to $chosen_network."
    fi
else
    # It's a new network, check if it requires a password
    sec=$(nmcli --get-values SSID,SECURITY dev wifi list | grep "^${chosen_network}:" | head -n1 | cut -d':' -f2)
    
    if [[ "$sec" == "" || "$sec" == "--" ]]; then
        notify-send "Wi-Fi" "Connecting to open network $chosen_network..."
        if nmcli dev wifi connect "$chosen_network"; then
            notify-send "Wi-Fi" "Successfully connected to $chosen_network."
        else
            notify-send "Wi-Fi" "Failed to connect to $chosen_network."
        fi
    else
        # Prompt for password
        # Since tofi doesn't have a built-in hidden password field, we just accept input
        password=$(echo "" | tofi --prompt-text "Password for $chosen_network: " --require-match false)
        
        if [ -z "$password" ]; then
            exit 0
        fi
        
        notify-send "Wi-Fi" "Connecting to $chosen_network..."
        if nmcli dev wifi connect "$chosen_network" password "$password"; then
            notify-send "Wi-Fi" "Successfully connected to $chosen_network."
        else
            notify-send "Wi-Fi" "Failed to connect. Incorrect password or network issue."
        fi
    fi
fi
