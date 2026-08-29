#!/bin/bash
# Helper script to list and control per-app audio streams via pactl.

case "${1:-list}" in
    list)
        python3 -c '
import subprocess, json

try:
    out = subprocess.check_output(["pactl", "list", "sink-inputs"], text=True, stderr=subprocess.DEVNULL)
except Exception:
    print("[]")
    exit(0)

inputs = []
current = None
for line in out.splitlines():
    line_str = line.strip()
    if line.startswith("Sink Input #"):
        if current and "id" in current:
            inputs.append(current)
        current = {
            "id": int(line.split("#")[1]),
            "muted": False,
            "volume": 1.0,
            "volume_pct": 100,
            "app_name": "",
            "node_name": "",
            "dev_desc": "",
            "binary": "",
            "icon": "",
            "media_name": "",
            "window_name": ""
        }
    elif current is not None:
        if line_str.startswith("Mute:"):
            current["muted"] = "yes" in line_str.lower()
        elif line_str.startswith("Volume:") and "%" in line_str:
            try:
                pct_str = line_str.split("%")[0].split("/")[-1].strip()
                pct = int(pct_str)
                current["volume_pct"] = pct
                current["volume"] = pct / 100.0
            except Exception:
                pass
        elif "application.name =" in line_str:
            current["app_name"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "device.description =" in line_str:
            current["dev_desc"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "node.name =" in line_str:
            current["node_name"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "application.icon_name =" in line_str or "application.icon-name =" in line_str:
            current["icon"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "application.process.binary =" in line_str:
            current["binary"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "media.name =" in line_str:
            current["media_name"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "window.name =" in line_str or "window.title =" in line_str:
            current["window_name"] = line_str.split("=", 1)[1].strip().strip("\"")

if current and "id" in current:
    inputs.append(current)

cleaned = []
for item in inputs:
    # Filter internal monitors, cava, speech-dispatcher
    name_check = (item["app_name"] + " " + item["node_name"] + " " + item["binary"]).lower()
    if "cava" in name_check or "quickshell" in name_check or "speech-dispatcher" in name_check:
        continue

    # Determine best readable name
    name = ""
    for candidate in [item["app_name"], item["dev_desc"], item["node_name"]]:
        if candidate and candidate.lower() not in ["playback stream", "alsa playback", "alsa stream", "audio stream"]:
            name = candidate
            break
    if not name:
        if item["media_name"] and item["media_name"].lower() not in ["playback stream", "alsa playback"]:
            name = item["media_name"]
        elif item["binary"]:
            name = item["binary"].replace("-", " ").title()
        else:
            name = "Audio"

    cleaned.append({
        "id": item["id"],
        "name": name,
        "binary": item["binary"] or item["node_name"],
        "icon": item["icon"] or item["node_name"],
        "muted": item["muted"],
        "volume": item["volume"],
        "volume_pct": item["volume_pct"]
    })

print(json.dumps(cleaned))
'
        ;;
    set-volume)
        ID="$2"
        VOL="$3"
        [ -n "$ID" ] && [ -n "$VOL" ] && pactl set-sink-input-volume "$ID" "${VOL}%" >/dev/null 2>&1
        ;;
    toggle-mute)
        ID="$2"
        [ -n "$ID" ] && pactl set-sink-input-mute "$ID" toggle >/dev/null 2>&1
        ;;
    set-mute)
        ID="$2"
        MUTE="$3"
        [ -n "$ID" ] && [ -n "$MUTE" ] && pactl set-sink-input-mute "$ID" "$MUTE" >/dev/null 2>&1
        ;;
esac
