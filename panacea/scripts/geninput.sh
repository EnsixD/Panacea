#!/usr/bin/env bash
# Build keyboard configuration for both Hyprland configuration paths.
set -euo pipefail

cfg="$HOME/.config/panacea/settings.json"
lua_out="$HOME/.config/hypr/lua/input_data.lua"
conf_out="$HOME/.config/hypr/input_data.conf"
[ -f "$cfg" ] && command -v jq >/dev/null 2>&1 || exit 1

layouts="$(jq -r '.keyboardLayouts // "us,ru"' "$cfg" | tr -d '[:space:]')"
variants="$(jq -r '.keyboardVariants // ","' "$cfg" | tr -d '[:space:]')"
options="$(jq -r '.keyboardOptions // "grp:alt_shift_toggle"' "$cfg" | tr -d '[:space:]')"

[[ "$layouts" =~ ^[A-Za-z0-9_,+-]+$ ]] || exit 1
[[ "$variants" =~ ^[A-Za-z0-9_,+-]*$ ]] || exit 1
[[ "$options" =~ ^[A-Za-z0-9_,:+-]*$ ]] || exit 1
[[ "$layouts" != ,* && "$layouts" != *, && "$layouts" != *,,* ]] || exit 1

layout_count="$(awk -F, '{print NF}' <<< "$layouts")"
variant_count="$(awk -F, '{print NF}' <<< "$variants")"
if [ "$layout_count" -ne "$variant_count" ]; then
    # Plain commas mean every layout uses its default variant.
    if [[ "$variants" =~ ^,*$ ]]; then
        variants="$(printf '%*s' "$((layout_count - 1))" '' | tr ' ' ',')"
    else
        echo "Keyboard variant count must match layout count" >&2
        exit 1
    fi
fi

mkdir -p "$(dirname "$lua_out")"
lua_tmp="$(mktemp "$lua_out.XXXXXX")"
conf_tmp="$(mktemp "$conf_out.XXXXXX")"
trap 'rm -f "$lua_tmp" "$conf_tmp"' EXIT

lua_layouts="$(jq -nr --arg value "$layouts" '$value | @json')"
lua_variants="$(jq -nr --arg value "$variants" '$value | @json')"
lua_options="$(jq -nr --arg value "$options" '$value | @json')"
printf 'return { layouts = %s, variants = %s, options = %s }\n' \
    "$lua_layouts" "$lua_variants" "$lua_options" > "$lua_tmp"
printf 'input {\n    kb_layout = "%s"\n    kb_variant = "%s"\n    kb_options = "%s"\n}\n' \
    "$layouts" "$variants" "$options" > "$conf_tmp"
mv -f "$lua_tmp" "$lua_out"
mv -f "$conf_tmp" "$conf_out"

if [ "${PANACEA_DRYRUN:-0}" != "1" ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
fi
