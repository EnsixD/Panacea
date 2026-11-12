#!/usr/bin/env bash
# This helper must run outside the shell service's cgroup.
set -u
conf="${XDG_CONFIG_HOME:-$HOME/.config}/panacea"
unset PANACEA_SERVICE_PROCESS PANACEA_WEBENGINE_READY
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
elif [ -n "${NIRI_SOCKET:-}" ]; then
    niri msg action load-config >/dev/null 2>&1 || true
fi
if command -v systemctl >/dev/null 2>&1 && systemctl --user cat panacea-shell.service >/dev/null 2>&1; then
    exec systemctl --user restart panacea-shell.service
fi
quickshell kill -p "$conf/shell.qml" >/dev/null 2>&1 || true
exec "$conf/scripts/start.sh"
