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
            name = (current.get("name") or "").lower()
            bin_name = (current.get("binary") or "").lower()
            if "cava" not in name and "cava" not in bin_name and "quickshell" not in name:
                inputs.append(current)
        current = {
            "id": int(line.split("#")[1]),
            "muted": False,
            "volume": 1.0,
            "volume_pct": 100,
            "name": "",
            "icon": "",
            "binary": ""
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
            current["name"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "application.icon_name =" in line_str or "application.icon-name =" in line_str:
            current["icon"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "application.process.binary =" in line_str:
            current["binary"] = line_str.split("=", 1)[1].strip().strip("\"")
        elif "media.name =" in line_str and not current.get("name"):
            current["name"] = line_str.split("=", 1)[1].strip().strip("\"")

if current and "id" in current:
    name = (current.get("name") or "").lower()
    bin_name = (current.get("binary") or "").lower()
    if "cava" not in name and "cava" not in bin_name and "quickshell" not in name:
        inputs.append(current)

print(json.dumps(inputs))
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
