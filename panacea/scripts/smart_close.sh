#!/bin/bash
# Smart window / overlay closer for Super+Q.
# Closes open Panacea overlays first if closePanaceaFirst is enabled in settings.

CFG="$HOME/.config/panacea/settings.json"
PREF=1

if [ -f "$CFG" ]; then
    VAL=$(jq -r '.closePanaceaFirst // true' "$CFG" 2>/dev/null)
    if [ "$VAL" = "false" ]; then
        PREF=0
    fi
fi

if [ "$PREF" = 1 ]; then
    OUT=$(qs -c "$HOME/.config/panacea" ipc call pill smartClose 2>/dev/null)
    if [ "$OUT" = "closed_overlay" ]; then
        exit 0
    fi
fi

# Close active window in Hyprland (supports both lua plugin dispatcher and standard killactive)
out=$(hyprctl dispatch 'hl.dsp.window.close()' 2>&1)
case "$out" in
    ok*) ;;
    *) hyprctl dispatch killactive >/dev/null 2>&1 ;;
esac
