#!/bin/bash
# Обои для страницы выбора.
#
#   list            -> строки  имя|миниатюра|активны(yes|no)|своя(yes|no)|полный_путь
#   set NAME        -> применить
#   add <путь>      -> скопировать файл в свои обои и применить
#   del NAME        -> удалить свои обои
#
# Тем как наборов цветов больше нет: палитра одна (hypr/palette.conf), и
# «тема» — это просто картинка. Поэтому список берётся прямо из каталога
# обоев, а не из themes/*.conf.

WALL_DIR="$HOME/.config/hypr/wallpaper"
CUSTOM="$WALL_DIR/custom"
STATE="$HOME/.config/hypr/wallpaper.conf"
SWITCH="$HOME/.config/hypr/scripts/switch_theme.sh"
THUMBS="$(dirname "$0")/thumbs.sh"
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/panacea/thumbs"

current() {
    grep -m1 '^\$wallpaper' "$STATE" 2>/dev/null \
        | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

case "$1" in
list)
    cur=$(current)
    # Всё в одном цикле на встроенных командах: обоев сотни, и подпроцессы
    # (basename, thumbs.sh) на каждую превращали список в пять секунд —
    # карусель успевала открыться пустой.
    find "$WALL_DIR" -maxdepth 2 -type f \
         \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
         | sort | while read -r w; do
        base=${w##*/}
        name=${base%.*}
        [ "$w" = "$cur" ] && act=yes || act=no
        case "$w" in "$CUSTOM"/*) own=yes ;; *) own=no ;; esac
        # Готовая миниатюра, если она есть и не устарела: исходники весят
        # мегабайты. Создавать их здесь нельзя — этим занимается «warm»,
        # а до тех пор показываем исходник, Qt ужмёт его по sourceSize.
        thumb="$THUMB_DIR/$name.jpg"
        [ -f "$thumb" ] && [ ! "$w" -nt "$thumb" ] || thumb="$w"
        printf '%s|%s|%s|%s|%s\n' "$name" "$thumb" "$act" "$own" "$w"
    done
    ;;

warm)
    # Догоняем миниатюры для новых обоев. Зовётся из карусели после открытия,
    # поэтому первое открытие быстрое, а второе — уже с миниатюрами.
    exec "$THUMBS" all
    ;;

set)
    [ -z "$2" ] && exit 1
    exec "$SWITCH" "$2"
    ;;

add)
    src="$2"
    [ -f "$src" ] || { echo "error" >&2; exit 1; }
    mkdir -p "$CUSTOM"

    # Если такой же файл уже добавлен в свои обои — используем его без дубликатов
    for existing in "$CUSTOM"/*; do
        if [ -f "$existing" ] && cmp -s "$src" "$existing"; then
            "$SWITCH" "$existing" >/dev/null 2>&1
            basename "$existing" | sed 's/\.[^.]*$//'
            exit 0
        fi
    done

    base=$(basename "$src")
    slug=$(printf '%s' "${base%.*}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' \
           | tr -cd '[:alnum:]_-')
    [ -z "$slug" ] && slug="wall_$(date +%s)"
    ext="${base##*.}"
    dest="$CUSTOM/$slug.$ext"
    # имя занято — не затираем чужую картинку молча
    [ -e "$dest" ] && dest="$CUSTOM/${slug}_$(date +%s).$ext"
    cp -f "$src" "$dest" || exit 1
    "$SWITCH" "$dest" >/dev/null 2>&1
    basename "$dest" | sed 's/\.[^.]*$//'
    ;;

del)
    [ -z "$2" ] && exit 1
    rm -f "$CUSTOM/$2".* 2>/dev/null
    ;;

*)
    echo "usage: themes.sh list | set <name> | add <file> | del <name>" >&2
    exit 1
    ;;
esac
