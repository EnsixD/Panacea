#!/bin/bash
# Обслуга медиаплеера пилюли.
#
#   probe PATH                  -> длительность|ширина|высота  (длительность 0 у картинок)
#   cut PATH START END [DIR] [X Y W H]
#                               -> вырезать кусок видео (и, если заданы X Y W H,
#                                  заодно обрезать кадр), печатает путь к файлу
#   crop PATH X Y W H [DIR]     -> вырезать область картинки, печатает путь
#
# DIR по умолчанию — папка оригинала. Имя не затирается: к нему добавляется
# «-cut»/«-crop» и, если такой уже есть, номер.

out_name() {
    local src="$1" dir="$2" suffix="$3" ext="$4"
    local base
    base=$(basename "$src")
    base="${base%.*}"
    local out="$dir/$base$suffix.$ext"
    local n=2
    while [ -e "$out" ]; do
        out="$dir/$base$suffix-$n.$ext"
        n=$((n + 1))
    done
    printf '%s\n' "$out"
}

case "$1" in
    probe)
        P="${2:?}"
        ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height -show_entries format=duration \
            -of default=nw=1:nk=1 "$P" 2>/dev/null | {
                read -r w; read -r h; read -r d
                printf '%s|%s|%s\n' "${d:-0}" "${w:-0}" "${h:-0}"
            }
        ;;

    cut)
        P="${2:?}"; START="${3:?}"; END="${4:?}"
        # Видео без звуковой дорожки мессенджеры показывают как «гифку»
        # и жмут в кашу. Если звука нет — подкладываем тишину.
        HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=index \
                            -of csv=p=0 "$P" 2>/dev/null | head -1)
        SILENCE=()
        AENC=(-c:a copy)
        if [ -z "$HAS_AUDIO" ]; then
            SILENCE=(-f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000")
            AENC=(-c:a aac -b:a 96k -shortest)
        fi
        DIR="${5:-$(dirname "$P")}"
        DIR="${DIR/#\~/$HOME}"
        X="$6"; Y="$7"; W="$8"; H="$9"
        mkdir -p "$DIR" || exit 1
        ext="${P##*.}"
        OUT=$(out_name "$P" "$DIR" "-cut" "$ext")

        if [ -n "$W" ] && [ "$W" != "0" ]; then
            # обрезка кадра требует пережатия: скопировать поток нельзя
            ffmpeg -v error -y -ss "$START" -to "$END" -i "$P" "${SILENCE[@]}" \
                   -vf "crop=$W:$H:$X:$Y" \
                   -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
                   "${AENC[@]}" -movflags +faststart "$OUT" </dev/null || exit 1
        else
            # -c copy режет по ключевым кадрам: быстро и без потери качества.
            # Если контейнер так не умеет — пережимаем.
            if ! ffmpeg -v error -y -ss "$START" -to "$END" -i "$P" "${SILENCE[@]}" \
                        -c:v copy "${AENC[@]}" -avoid_negative_ts make_zero \
                        -movflags +faststart "$OUT" </dev/null; then
                ffmpeg -v error -y -ss "$START" -to "$END" -i "$P" "${SILENCE[@]}" \
                       -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
                       "${AENC[@]}" -movflags +faststart "$OUT" </dev/null || exit 1
            fi
        fi
        printf '%s\n' "$OUT"
        ;;

    crop)
        P="${2:?}"; X="${3:?}"; Y="${4:?}"; W="${5:?}"; H="${6:?}"
        DIR="${7:-$(dirname "$P")}"
        DIR="${DIR/#\~/$HOME}"
        mkdir -p "$DIR" || exit 1
        ext="${P##*.}"
        case "${ext,,}" in
            gif|png|jpg|jpeg|webp|bmp) : ;;
            *) ext="png" ;;
        esac
        OUT=$(out_name "$P" "$DIR" "-crop" "$ext")
        args=(-v error -y -i "$P" -vf "crop=$W:$H:$X:$Y")
        # анимацию гифки сохраняем целиком, просто обрезанной по кадру
        [ "${ext,,}" = "gif" ] && args+=(-loop 0)
        ffmpeg "${args[@]}" "$OUT" </dev/null || exit 1
        printf '%s\n' "$OUT"
        ;;

    *)
        echo "usage: media.sh probe P | cut P START END [DIR] | crop P X Y W H [DIR]" >&2
        exit 1
        ;;
esac
