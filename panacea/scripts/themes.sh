#!/bin/bash
# Список тем Hyprland для страницы выбора.
#
#   list     -> строки  имя|путь_к_обоям|активна(yes|no)
#   set NAME -> применить тему

THEMES="$HOME/.config/hypr/themes"
CURRENT="$HOME/.config/hypr/theme.conf"
SWITCH="$HOME/.config/hypr/scripts/switch_theme.sh"

wallpaper_of() {
    grep -m1 '^\$wallpaper' "$1" 2>/dev/null \
        | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

case "$1" in
    list)
        cur_wall=$(wallpaper_of "$CURRENT")
        for f in "$THEMES"/*.conf; do
            [ -f "$f" ] || continue
            name=$(basename "$f" .conf)
            wall=$(wallpaper_of "$f")
            if [ "$wall" = "$cur_wall" ]; then act=yes; else act=no; fi
            # отдаём миниатюру: исходники весят мегабайты и грузятся заметно
            thumb=$("$(dirname "$0")/thumbs.sh" thumb "$wall" 2>/dev/null)
            [ -n "$thumb" ] || thumb="$wall"
            printf '%s|%s|%s\n' "$name" "$thumb" "$act"
        done
        ;;
    set)
        [ -z "$2" ] && exit 1
        exec "$SWITCH" "$2"
        ;;
    *)
        echo "usage: themes.sh list | set <name>" >&2
        exit 1
        ;;
esac
