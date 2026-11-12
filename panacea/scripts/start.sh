#!/usr/bin/env bash
# Start Quickshell with the QtWebEngine argv workaround when it is available.
set -u
conf="${XDG_CONFIG_HOME:-$HOME/.config}/panacea"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/panacea"
# Keep the shell independent of the terminal or updater that launched it.
if [ "${PANACEA_SERVICE_PROCESS:-0}" != "1" ] && command -v systemctl >/dev/null 2>&1 && [ -f "$conf/panacea-shell.service" ]; then
    units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$units"
    if ! cmp -s "$conf/panacea-shell.service" "$units/panacea-shell.service"; then
        cp "$conf/panacea-shell.service" "$units/panacea-shell.service"
        systemctl --user daemon-reload
    fi
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP >/dev/null 2>&1 || true
    if systemctl --user start panacea-shell.service; then exit 0; fi
fi
plugin=/usr/lib/qt6/qml/QtWebEngine/qmldir
source_file="$conf/scripts/webengine-argv.cpp"
lib="$cache/webengine-argv.so"
compat="${XDG_DATA_HOME:-$HOME/.local/share}/panacea/compat-lib"
# Existing local installations may keep their compatibility libraries here.
[ -d "$compat" ] || compat="$HOME/.local/lib/panacea-compat"
export QSG_RENDER_LOOP="${QSG_RENDER_LOOP:-threaded}"
# Dunst can be D-Bus activated while Panacea is restarting and then owns the
# notification name. Stop only this competing service when Panacea's own
# notification server is enabled; Dunst remains available when Panacea exits.
settings="$conf/settings.json"
if ! command -v jq >/dev/null 2>&1 || [ ! -f "$settings" ] || ! jq -e '.featNotifications == false' "$settings" >/dev/null 2>&1; then
    systemctl --user stop dunst.service >/dev/null 2>&1 || true
fi
unset PANACEA_WEBENGINE_READY
if [ -f "$plugin" ] && [ -f "$source_file" ] && command -v g++ >/dev/null 2>&1 && command -v pkg-config >/dev/null 2>&1 && pkg-config --exists Qt6Core; then
    mkdir -p "$cache"
    if [ ! -s "$lib" ] || [ "$source_file" -nt "$lib" ]; then
        g++ -shared -fPIC "$source_file" -o "$lib.tmp" $(pkg-config --cflags --libs Qt6Core) -ldl >/dev/null 2>&1 && mv -f "$lib.tmp" "$lib"
    fi
    webplugin=/usr/lib/qt6/qml/QtWebEngine/libqtwebenginequickplugin.so
    search_path="${LD_LIBRARY_PATH:-}"
    [ -d "$compat" ] && search_path="$compat${search_path:+:$search_path}"
    if [ -s "$lib" ] && [ -f "$webplugin" ] && ! LD_LIBRARY_PATH="$search_path" ldd "$webplugin" 2>/dev/null | grep -q "not found"; then
        export PANACEA_WEBENGINE_READY=1
        export PANACEA_ORIGINAL_LD_PRELOAD="${LD_PRELOAD:-}"
        export LD_PRELOAD="$lib${LD_PRELOAD:+:$LD_PRELOAD}"
        if [ -d "$compat" ]; then export LD_LIBRARY_PATH="$compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
    fi
fi
exec qs -p "$conf"
