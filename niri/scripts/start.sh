#!/usr/bin/env bash
# Точка входа в сеанс Niri с окружением Panacea.

export XDG_CURRENT_DESKTOP=niri
export XDG_SESSION_DESKTOP=niri
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM="wayland;xcb"
export GDK_BACKEND="wayland,x11,*"
export MOZ_ENABLE_WAYLAND=1
export ELECTRON_OZONE_PLATFORM_HINT=auto

exec niri --session "$@"
