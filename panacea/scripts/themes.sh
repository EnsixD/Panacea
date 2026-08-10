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
            case "$wall" in *"/wallpaper/custom/"*) custom=yes ;; *) custom=no ;; esac
            printf '%s|%s|%s|%s\n' "$name" "$thumb" "$act" "$custom"
        done
        ;;
    set)
        [ -z "$2" ] && exit 1
        exec "$SWITCH" "$2"
        ;;
    add)
        # add "Красивое имя" /path/to/wall.jpg
        # Своя тема = копия текущей, где подменены только обои. Так меняется
        # именно фон, а палитра остаётся той, что нравится сейчас. Файл .conf
        # ложится в themes/ и потому переживает перезапуск сам собой.
        name="$2"; src="$3"
        [ -n "$name" ] && [ -f "$src" ] || { echo "error" >&2; exit 1; }
        slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' \
               | tr -cd '[:alnum:]_-')
        [ -z "$slug" ] && slug="wall_$(date +%s)"

        wdir="$HOME/.config/hypr/wallpaper/custom"
        mkdir -p "$wdir"
        ext="${src##*.}"
        dest="$wdir/$slug.$ext"
        cp -f "$src" "$dest" || exit 1

        out="$THEMES/$slug.conf"
        if grep -q '^\$wallpaper' "$CURRENT"; then
            sed "s|^\$wallpaper[[:space:]]*=.*|\$wallpaper = $dest|" "$CURRENT" > "$out"
        else
            cp "$CURRENT" "$out"
            printf '\n$wallpaper = %s\n' "$dest" >> "$out"
        fi
        # сразу применяем добавленные обои
        "$SWITCH" "$slug" >/dev/null 2>&1
        echo "$slug"
        ;;
    del)
        # удалить свою тему обоев (и её файл)
        [ -z "$2" ] && exit 1
        rm -f "$THEMES/$2.conf"
        rm -f "$HOME/.config/hypr/wallpaper/custom/$2".* 2>/dev/null
        ;;
    *)
        echo "usage: themes.sh list | set <name> | add <name> <file> | del <name>" >&2
        exit 1
        ;;
esac
