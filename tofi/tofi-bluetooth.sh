#!/bin/bash
notify-send "Bluetooth" "Scanning for devices..." -t 2000

# Power state
if ! bluetoothctl show >/dev/null 2>&1; then
    notify-send "Bluetooth" "No Bluetooth controller found."
    exit 1
fi

power_state=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

if [ "$power_state" == "yes" ]; then
    toggle_power="Power Off"
else
    toggle_power="Power On"
fi

# Get devices
connected_macs=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')
devices=$(bluetoothctl devices 2>/dev/null | grep "^Device" | awk -v connected="$connected_macs" '
BEGIN {
    split(connected, conn_arr, "\n");
    for (i in conn_arr) {
        if (conn_arr[i] != "")
            is_conn[conn_arr[i]] = 1;
    }
}
{
    mac=$2
    $1=""; $2=""; name=substr($0,3);
    
    display_name = name
    if (name ~ /^[0-9A-Fa-f:-]+$/) {
        display_name = "Unknown (" name ")"
    }

    if (is_conn[mac]) {
        print display_name " (connected)"
    } else {
        print display_name
    }
}')

# Build menu
if [ -z "$devices" ]; then
    options="$toggle_power\nScan Devices"
else
    options="$toggle_power\nScan Devices\n$devices"
fi

chosen=$(echo -e "$options" | tofi --prompt-text "Bluetooth: ")

if [ -z "$chosen" ]; then
    exit 0
fi

if [ "$chosen" == "Power On" ]; then
    bluetoothctl power on
    notify-send "Bluetooth" "Powered On"
    exit 0
elif [ "$chosen" == "Power Off" ]; then
    bluetoothctl power off
    notify-send "Bluetooth" "Powered Off"
    exit 0
elif [ "$chosen" == "Scan Devices" ]; then
    notify-send "Bluetooth" "Scanning for 10 seconds..."
    bluetoothctl --timeout 10 scan on
    exec "$0"
fi

# Strip " (connected)" if present
chosen_device="${chosen% (connected)}"

# Strip "Unknown (" and ")" if present
if [[ "$chosen_device" == "Unknown ("*")" ]]; then
    chosen_device="${chosen_device#Unknown (}"
    chosen_device="${chosen_device%)}"
fi

# Find the MAC address for the chosen device
mac=$(bluetoothctl devices | grep -m 1 "$chosen_device" | awk '{print $2}')

if [ -n "$mac" ]; then
    connected=$(bluetoothctl info "$mac" | grep "Connected:" | awk '{print $2}')
    trusted=$(bluetoothctl info "$mac" | grep "Trusted:" | awk '{print $2}')
    paired=$(bluetoothctl info "$mac" | grep "Paired:" | awk '{print $2}')
    
    action_connect="Connect"
    [ "$connected" == "yes" ] && action_connect="Disconnect"
    
    action_trust="Trust"
    [ "$trusted" == "yes" ] && action_trust="Untrust"
    
    submenu_options="$action_connect\n$action_trust\nPair\nRemove\nCancel"

    action=$(echo -e "$submenu_options" | tofi --prompt-text "Action: ")

    case "$action" in
        "Connect")
            if [ "$paired" != "yes" ]; then
                notify-send "Bluetooth" "Pairing with $chosen_device..."
                (
                    echo "agent KeyboardDisplay"
                    echo "default-agent"
                    echo "pair $mac"
                    sleep 5
                    echo "trust $mac"
                    echo "exit"
                ) | bluetoothctl > /dev/null
                
                # Check if pairing was actually successful
                if ! bluetoothctl info "$mac" | grep -q "Paired: yes"; then
                    notify-send "Bluetooth" "Failed to pair with $chosen_device."
                    exit 1
                fi
                # Give BlueZ a moment to register audio profiles before connecting
                sleep 2
            fi
            bluetoothctl trust "$mac"
            notify-send "Bluetooth" "Connecting to $chosen_device..."
            if bluetoothctl connect "$mac"; then notify-send "Bluetooth" "Connected to $chosen_device."; else notify-send "Bluetooth" "Failed to connect."; fi
            ;;
        "Disconnect")
            notify-send "Bluetooth" "Disconnecting from $chosen_device..."
            if bluetoothctl disconnect "$mac"; then notify-send "Bluetooth" "Disconnected from $chosen_device."; else notify-send "Bluetooth" "Failed to disconnect."; fi
            ;;
        "Trust")
            if bluetoothctl trust "$mac"; then notify-send "Bluetooth" "Trusted $chosen_device."; else notify-send "Bluetooth" "Failed to trust."; fi
            ;;
        "Untrust")
            if bluetoothctl untrust "$mac"; then notify-send "Bluetooth" "Untrusted $chosen_device."; else notify-send "Bluetooth" "Failed to untrust."; fi
            ;;
        "Pair")
            notify-send "Bluetooth" "Pairing with $chosen_device..."
            (
                echo "agent KeyboardDisplay"
                echo "default-agent"
                echo "pair $mac"
                sleep 5
                echo "trust $mac"
                echo "exit"
            ) | bluetoothctl > /dev/null
            if bluetoothctl info "$mac" | grep -q "Paired: yes"; then notify-send "Bluetooth" "Paired with $chosen_device."; else notify-send "Bluetooth" "Failed to pair."; fi
            ;;
        "Remove")
            if bluetoothctl remove "$mac"; then notify-send "Bluetooth" "Removed $chosen_device."; else notify-send "Bluetooth" "Failed to remove."; fi
            ;;
        *)
            exit 0
            ;;
    esac
fi
