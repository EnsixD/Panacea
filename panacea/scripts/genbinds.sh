#!/bin/bash
# Пересобирает ~/.config/hypr/lua/binds_data.lua из settings.json
# и просит Hyprland перечитать конфиг.
#
# Берутся все ключи вида bind_<id>. Значение "" означает, что
# сочетание отключено — keybindings.lua такие пропускает.

CFG="$HOME/.config/panacea/settings.json"
OUT="$HOME/.config/hypr/lua/binds_data.lua"

[ -f "$CFG" ] || exit 1

{
    echo "-- Файл создаётся автоматически панелью настроек пилюли (Super+I)."
    echo "-- Правки руками будут затёрты при следующей смене сочетания."
    echo "return {"
    jq -r '
        to_entries
        | map(select(.key | startswith("bind_")))
        | sort_by(.key)
        | .[]
        | "    [\"" + (.key | sub("^bind_"; "")) + "\"] = " + (.value | tostring | @json) + ","
    ' "$CFG"
    echo "}"
} > "$OUT"

hyprctl reload >/dev/null 2>&1
