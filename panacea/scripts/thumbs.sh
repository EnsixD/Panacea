#!/bin/bash
# Миниатюры обоев для страницы выбора темы.
#
# Обои весят до 9 МБ, и Qt при каждом открытии страницы декодировал их
# целиком, чтобы получить картинку шириной 320 px — отсюда задержка.
# Здесь они один раз ужимаются в ~/.cache/panacea/thumbs и дальше читаются
# мгновенно. Перегенерация только если исходник новее миниатюры.
#
#   thumb PATH -> печатает путь к миниатюре (создав её при необходимости)
#   all        -> прогреть кеш для всех обоев

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/panacea/thumbs"
WALLS="$HOME/.config/hypr/wallpaper"
WIDTH=480

mkdir -p "$CACHE"

make_thumb() {
    local src="$1"
    [ -f "$src" ] || return 1

    local name
    name=$(basename "$src")
    name="${name%.*}.jpg"
    local dst="$CACHE/$name"

    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        # -noautorotate не нужен, обои без EXIF; q=5 хватает для превью
        ffmpeg -loglevel error -y -i "$src" \
               -vf "scale=$WIDTH:-1" -q:v 5 "$dst" </dev/null || return 1
    fi
    printf '%s\n' "$dst"
}

case "$1" in
    thumb)
        make_thumb "$2"
        ;;
    all)
        for f in "$WALLS"/*.jpg "$WALLS"/*.png; do
            [ -f "$f" ] || continue
            make_thumb "$f" >/dev/null
        done
        ;;
    *)
        echo "usage: thumbs.sh thumb <path> | all" >&2
        exit 1
        ;;
esac
