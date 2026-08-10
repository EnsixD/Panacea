#!/bin/bash

# --- 1. GESTIONE ARGOMENTI ---
# Ultimo tema scelto: serve a ripristinarlo al riavvio (--restore).
STATE_FILE="$HOME/.config/hypr/.current-theme"
DEFAULT_THEME="dark_mountains"

if [ "$1" = "--restore" ]; then
    THEME_NAME=$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')
    [ -z "$THEME_NAME" ] && THEME_NAME="$DEFAULT_THEME"
elif [ -n "$1" ]; then
    THEME_NAME="$1"
else
    THEME_NAME=$(ls ~/.config/hypr/themes/*.conf | xargs -n 1 basename | sed 's/\.conf//' | tofi --prompt-text " Tema: ")
fi

[ -z "$THEME_NAME" ] && exit 0
THEME_FILE="$HOME/.config/hypr/themes/$THEME_NAME.conf"

# tema salvato ma sparito dal disco: torniamo al default
if [ ! -f "$THEME_FILE" ]; then
    THEME_NAME="$DEFAULT_THEME"
    THEME_FILE="$HOME/.config/hypr/themes/$THEME_NAME.conf"
    [ -f "$THEME_FILE" ] || exit 1
fi

# ricordiamo la scelta prima di applicarla
printf '%s\n' "$THEME_NAME" > "$STATE_FILE"

# --- 2. APPLICAZIONE TEMA HYPRLAND ---
cp "$THEME_FILE" "$HOME/.config/hypr/theme.conf"

# --- 2.5 GENERAZIONE TEMA LUA ---
while IFS='=' read -r key value; do
    [[ $key =~ ^\$ ]] || continue
    var_name=$(echo "${key//\$/}" | xargs)
    var_value=$(echo "$value" | xargs)
    declare "$var_name"="$var_value"
done < "$THEME_FILE"

# Convert $active_border (multiple rgba + angle) to Lua table
ACTIVE_COLORS=$(echo "$active_border" | grep -o "rgba([^)]*)" | sed 's/^/"/;s/$/"/' | paste -sd, -)
ACTIVE_ANGLE=$(echo "$active_border" | grep -o "[0-9]\+deg" | sed 's/deg//' || echo 45)

cat > ~/.config/hypr/theme.lua <<EOF
return {
    gaps_in = $gaps_in,
    gaps_out = $gaps_out,
    border_size = $border_size,
    active_border = { colors = { $ACTIVE_COLORS }, angle = $ACTIVE_ANGLE },
    inactive_border = "$inactive_border",
    rounding = $rounding,
    rounding_power = $rounding_power,
    active_opacity = $active_opacity,
    inactive_opacity = $inactive_opacity,
    shadow_enabled = $( [[ "$shadow_enabled" == "true" ]] && echo "true" || echo "false" ),
    shadow_range = $shadow_range,
    shadow_render_power = $shadow_render_power,
    shadow_color = "$shadow_color",
    blur_enabled = $( [[ "$blur_enabled" == "true" ]] && echo "true" || echo "false" ),
    blur_size = $blur_size,
    blur_passes = $blur_passes,
    blur_vibrancy = $blur_vibrancy,
}
EOF

# --- 3. ESTRAZIONE VARIABILI ---
WALLPAPER=$(grep '$wallpaper' "$THEME_FILE" | awk -F'=' '{print $2}' | xargs)
ACCENT=$(grep '$accent_color' "$THEME_FILE" | awk -F'=' '{print $2}' | xargs)
BG=$(grep '$bg_color' "$THEME_FILE" | awk -F'=' '{print $2}' | xargs)
FG=$(grep '$fg_color' "$THEME_FILE" | awk -F'=' '{print $2}' | xargs)
# Необязательный $term_bg: фон терминалов может быть темнее общего фона темы.
# Если в теме его нет — берём обычный bg.
TERM_BG=$(grep '$term_bg' "$THEME_FILE" | awk -F'=' '{print $2}' | xargs)
[ -z "$TERM_BG" ] && TERM_BG="$BG"
TOFI_SEL=$(grep '$tofi_selection' "$THEME_FILE" | awk -F'=' '{print $2}' | xargs)

# Fallback
[[ ! $ACCENT =~ ^# ]] && ACCENT="#ffffff"
[[ ! $BG =~ ^# ]] && BG="#000000"
[[ ! $FG =~ ^# ]] && FG="#ffffff"

if [[ "$THEME_NAME" == "nero" || "$THEME_NAME" == "black" || "$THEME_NAME" == "earth" || "$THEME_NAME" == "minimal" ]]; then
    ACCENT="#ffffff" ; BG="#000000" ; FG="#ffffff" ; TOFI_SEL="#ff0000"
fi
[ -z "$TOFI_SEL" ] && TOFI_SEL=$ACCENT

# --- 4. SINCRONIZZAZIONE TOFI ---
for CONFIG in "config" "configpowermenu"; do
cat > ~/.config/tofi/$CONFIG <<EOF
anchor = top
width = 100%
height = $( [ "$CONFIG" == "config" ] && echo 25 || echo 30 )
horizontal = true
font-size = 10
prompt-text = " $( [ "$CONFIG" == "config" ] && echo "run:" || echo "Action:" ) "
font = JetBrainsMono Nerd Font
outline-width = 0
border-width = 0
min-input-width = 120
result-spacing = 25
padding-top = 5
padding-bottom = 5
padding-left = 10
padding-right = 10
background-color = $BG
text-color = $FG
selection-color = $TOFI_SEL
selection-background = #00000000
EOF
done

# --- 5. FASTFETCH ---
# Подписи и логотип красим акцентом темы. В конфиге строки помечены
# комментарием panacea:accent — переписываем ровно следующую за ним.
FF="$HOME/.config/fastfetch/config.jsonc"
if [ -f "$FF" ]; then
    R=$((16#${ACCENT:1:2})); G=$((16#${ACCENT:3:2})); B=$((16#${ACCENT:5:2}))
    awk -v rgb="38;2;$R;$G;$B" '
        prev ~ /panacea:accent/ { gsub(/38;2;[0-9]+;[0-9]+;[0-9]+/, rgb) }
        { print; prev = $0 }
    ' "$FF" > "$FF.new" && mv "$FF.new" "$FF"
fi

# --- 5. KITTY, GHOSTTY & WAYBAR ---
printf "@define-color accent %s;\n@define-color bg %s;\n@define-color fg %s;\n" "$ACCENT" "$BG" "$FG" > ~/.config/waybar/theme.css
cat > ~/.config/kitty/theme.conf <<EOF
foreground $FG
background $TERM_BG
cursor $ACCENT
EOF

# Ghostty
cat > ~/.config/ghostty/theme <<EOF
foreground = $FG
background = $TERM_BG
cursor-color = $ACCENT
EOF

# Foot
# Foot doesn't want the '#' in its color values
FOOT_BG=$(echo $TERM_BG | sed 's/#//')
FOOT_FG=$(echo $FG | sed 's/#//')
FOOT_ACCENT=$(echo $ACCENT | sed 's/#//')
cat > ~/.config/foot/theme <<EOF
[colors-dark]
foreground=$FOOT_FG
background=$FOOT_BG
selection-foreground=$FOOT_BG
selection-background=$FOOT_FG
EOF

# Секцию [colors-dark] foot читает, только если портал сообщает
# color-scheme=prefer-dark. По умолчанию в системе стоит «default», и тема
# молча игнорировалась: терминал оставался на сером 242424 вместо нашего
# почти чёрного фона. Темы у нас все тёмные — заявляем это один раз здесь.
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

# --- 6. PYTHON: FISH, ZED & BTOP ---
python3 <<EOF
import json, os, colorsys, re

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return '{:02x}{:02x}{:02x}'.format(int(rgb[0]*255), int(rgb[1]*255), int(rgb[2]*255))

accent = "$ACCENT"
theme_name = "$THEME_NAME"
bg = "$BG"
fg = "$FG"

r, g, b = [x/255.0 for x in hex_to_rgb(accent)]
h, s, v = colorsys.rgb_to_hsv(r, g, b)

# Calcolo colori soft per sintassi
if theme_name in ["nero", "black", "earth", "minimal"]:
    syntax_accent = accent
    color_param = "888888"
    color_quote = "aaaaaa"
else:
    syntax_accent = rgb_to_hex(colorsys.hsv_to_rgb(h, s * 0.55, v * 0.85))
    color_param = rgb_to_hex(colorsys.hsv_to_rgb(h, s * 0.35, v * 0.7))
    color_quote = rgb_to_hex(colorsys.hsv_to_rgb(h, s * 0.45, v * 0.8))

# 1. FISH
fish_path = os.path.expanduser('~/.config/fish/conf.d/theme_colors.fish')
with open(fish_path, 'w') as f:
    f.write(f"set -e fish_color_command\nset -e fish_color_param\n")
    f.write(f"set -g fish_color_command #{syntax_accent} --bold\n")
    f.write(f"set -g fish_color_param #{color_param}\n")
    f.write(f"set -g fish_color_quote #{color_quote}\n")
    f.write(f"set -g fish_color_redirection {accent}\n")
    f.write(f"set -g fish_color_end {accent}\n")
    f.write(f"set -g fish_color_error ff5555\n")
    f.write(f"set -g fish_color_selection --background={accent} --foreground={bg}\n")
    f.write(f"set -g fish_color_autosuggestion 707070\n")

# 2. ZED EDITOR (RIPRISTINATO COMPLETO)
zed_path = os.path.expanduser('~/.config/zed/settings.json')
zed_installed = os.path.exists(zed_path)
zed_data = {}
if zed_installed:
    with open(zed_path, 'r') as f:
        try: zed_data = json.load(f)
        except: zed_data = {}

accent_mute = f"{accent}33"
accent_very_mute = f"{accent}15"

if theme_name in ["nero", "black", "earth", "minimal"]:
    zed_data['experimental.theme_overrides'] = {}
else:
    zed_data['experimental.theme_overrides'] = {
            "background": bg, "editor.background": bg, "pane.background": bg,
            "pane.inactive_background": bg, "side_bar.background": bg,
            "status_bar.background": bg, "title_bar.background": bg,
            "toolbar.background": bg, "tab_bar.background": bg,
            "project_panel.background": bg, "terminal.background": bg,
            "panel.background": bg, "search.background": bg,
            "editor.gutter.background": bg, "menu.background": bg,
            "popover.background": bg, "picker.background": bg,
            "elevated_surface.background": bg, "context_menu.background": bg,
            "dropdown.background": bg, "border": accent_mute,
            "border.variant": accent_mute, "element.active": accent_mute,
            "element.selected": accent_mute, "element.hover": accent_very_mute,
            "tab.active_background": accent_very_mute, "active_tab.border": accent,
            "scrollbar.thumb.background": accent_mute, "text": fg,
            "editor.foreground": fg, "editor.active_line_number.foreground": accent,
            "editor.line_number.foreground": f"#{color_param}",
            "syntax": {
                "comment": {"color": "#606060"},
                "string": {"color": f"#{color_quote}"},
                "keyword": {"color": f"#{syntax_accent}"},
                "function": {"color": f"#{syntax_accent}"},
                "type": {"color": f"#{syntax_accent}"},
                "operator": {"color": f"#{syntax_accent}"},
                "property": {"color": f"#{color_param}"},
                "variable": {"color": fg}
            }
        }

if zed_installed:
    with open(zed_path, 'w') as f:
        json.dump(zed_data, f, indent=4)

# 3. BTOP
btop_theme_dir = os.path.expanduser('~/.config/btop/themes')
if not os.path.exists(btop_theme_dir): os.makedirs(btop_theme_dir)
btop_theme_path = os.path.join(btop_theme_dir, 'dynamic.theme')
with open(btop_theme_path, 'w') as f:
    btop_bg = "" if theme_name in ["nero", "black", "earth", "minimal"] else bg
    f.write(f'theme[main_bg]="{btop_bg}"\ntheme[main_fg]="{fg}"\ntheme[title]="{fg}"\n')
    f.write(f'theme[hi_fg]="{accent}"\ntheme[selected_bg]="#{accent_mute.lstrip("#")}"\n')
    f.write(f'theme[selected_fg]="{accent}"\ntheme[inactive_fg]="#555555"\n')
    f.write(f'theme[proc_misc]="{accent}"\ntheme[cpu_box]="{accent}"\n')
    f.write(f'theme[mem_box]="{accent}"\ntheme[net_box]="{accent}"\n')
    f.write(f'theme[proc_box]="{accent}"\ntheme[div_line]="#333333"\n')
    f.write(f'theme[free_graph]="{accent}"\ntheme[cached_graph]="#{color_param}"\n')
    f.write(f'theme[available_graph]="#{color_quote}"\ntheme[used_graph]="{accent}"\n')
    f.write(f'theme[download_graph]="{accent}"\ntheme[upload_graph]="#{color_param}"\n')

btop_conf_path = os.path.expanduser('~/.config/btop/btop.conf')
if os.path.exists(btop_conf_path):
    with open(btop_conf_path, 'r') as f: content = f.read()
    content = re.sub(r'color_theme = .*', 'color_theme = "dynamic.theme"', content)
    with open(btop_conf_path, 'w') as f: f.write(content)

# 4. NEOVIM (Generazione palette dinamica)
nvim_dir = os.path.expanduser('~/.config/nvim/lua')
if not os.path.exists(nvim_dir): os.makedirs(nvim_dir)
nvim_path = os.path.join(nvim_dir, 'theme_colors.lua')

# Puliamo i colori per assicurarci che siano a 6 cifre per Neovim
def clean_hex(h):
    return h[:7] if h.startswith('#') else f"#{h[:6]}"

with open(nvim_path, 'w') as f:
    f.write(f'return {{\n')
    f.write(f'    bg = "{clean_hex(bg)}",\n')
    f.write(f'    fg = "{clean_hex(fg)}",\n')
    f.write(f'    accent = "{clean_hex(accent)}",\n')
    f.write(f'    syntax = "{clean_hex(syntax_accent)}",\n')
    f.write(f'    param = "{clean_hex(color_param)}",\n')
    f.write(f'    string = "{clean_hex(color_quote)}",\n')
    f.write(f'    selection = "{clean_hex(accent)}",\n') # Niente 33 finale qui
    f.write(f'}}\n')

EOF



# --- 7. OBSIDIAN ---
OBSIDIAN_SNIPPET="$HOME/obsidian_vault/.obsidian/snippets/system-theme.css"
if [ -d "$HOME/obsidian_vault/.obsidian" ]; then
    if [[ "$THEME_NAME" == "nero" || "$THEME_NAME" == "black" || "$THEME_NAME" == "earth" || "$THEME_NAME" == "minimal" ]]; then
        echo "/* Reset */" > "$OBSIDIAN_SNIPPET"
    else
        cat > "$OBSIDIAN_SNIPPET" <<EOF
:root { --system-accent: $ACCENT; --system-bg: $BG; --system-fg: $FG; }
.theme-dark, .theme-light {
    --accent-component: var(--system-accent) !important;
    --interactive-accent: var(--system-accent) !important;
    --background-primary: var(--system-bg) !important;
    --background-secondary: var(--system-bg) !important;
    --text-normal: var(--system-fg) !important;
}
EOF
    fi
fi

# --- 8. HYPRPAPER & REFRESH ---
WALLPAPER="${WALLPAPER/#\~/$HOME}"
if [ "$WALLPAPER" != "black" ] && [ -f "$WALLPAPER" ]; then
    {
        printf "preload = %s\n" "$WALLPAPER"
        # una riga per ogni monitor collegato: ",path" non funziona su questa versione
        hyprctl monitors -j | jq -r '.[].name' | while read -r M; do
            printf "wallpaper = %s,%s\n" "$M" "$WALLPAPER"
        done
        printf "splash = false\nipc = on\n"
    } > ~/.config/hypr/hyprpaper.conf
    pgrep -x "hyprpaper" > /dev/null || hyprpaper &
    sleep 1
    hyprctl hyprpaper preload "$WALLPAPER" > /dev/null 2>&1
    hyprctl monitors -j | jq -r '.[].name' | while read -r M; do
        hyprctl hyprpaper wallpaper "$M,$WALLPAPER" > /dev/null 2>&1
    done
else
    pkill hyprpaper
fi

killall -SIGUSR2 waybar > /dev/null 2>&1
killall -USR1 kitty > /dev/null 2>&1
