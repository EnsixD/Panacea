#!/bin/bash
# Живые обои: видео вместо картинки на фоне рабочего стола.
#
#   dir            -> печатает каталог живых обоев (создав его)
#   list           -> строки  имя|постер|активны(yes|no)|путь
#   set <путь|имя> -> поставить видео фоном
#   stop           -> вернуть обычные обои
#   state          -> печатает путь текущего видео или пусто
#   warm           -> догнать постеры для всех видео
#
# Играет mpvpaper: он кладёт mpv на слой background, поэтому окна и пилюля
# остаются сверху. hyprpaper на это время выключается — два фоновых слоя
# спорили бы за один и тот же экран.
#
# Состояние живёт в wallpaper.conf рядом с обычными обоями ($live). Файл никто
# не подключает через source, поэтому смена фона не трогает конфиги Hyprland.

LIVE_DIR="$HOME/.config/hypr/wallpaper/live"
STATE="$HOME/.config/hypr/wallpaper.conf"
THUMBS="${XDG_CACHE_HOME:-$HOME/.cache}/panacea/thumbs"
SWITCH="$(dirname "$0")/switch_theme.sh"

mkdir -p "$LIVE_DIR"

live_state() {
    grep -m1 '^\$live' "$STATE" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}
still_state() {
    grep -m1 '^\$wallpaper' "$STATE" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

# Пишем $live, сохраняя строку с обычными обоями: к ней возвращаемся по stop.
save_live() {
    local v="$1" still
    still=$(still_state)
    {
        printf '# Файл создаётся автоматически при смене обоев.\n'
        printf '# Hyprland его не подключает: смена картинки не должна трогать конфиг.\n'
        printf '$wallpaper = %s\n' "$still"
        [ -n "$v" ] && printf '$live = %s\n' "$v"
    } > "$STATE"
}

poster() {
    # Кадр из середины видео — превью для карусели. Кладём в общий кеш
    # миниатюр: карусель читает и картинки, и видео из одного места.
    local src="$1" name dst dur pos
    name=$(basename "$src"); name="${name%.*}.jpg"
    dst="$THUMBS/$name"
    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        mkdir -p "$THUMBS"
        dur=$(ffprobe -v error -show_entries format=duration \
                      -of default=nw=1:nk=1 "$src" 2>/dev/null)
        pos=$(awk -v d="$dur" 'BEGIN{ if (d > 2) printf "%.1f", d/2; else print 0 }')
        ffmpeg -loglevel error -y -ss "$pos" -i "$src" -frames:v 1 \
               -vf "scale=1100:-1" -q:v 5 "$dst" </dev/null || return 1
    fi
    printf '%s\n' "$dst"
}

resolve() {
    local n="$1"
    n="${n/#\~/$HOME}"
    [ -f "$n" ] && { printf '%s\n' "$n"; return 0; }
    find "$LIVE_DIR" -maxdepth 1 -type f -iname "$n.*" -print -quit | grep . && return 0
    return 1
}

case "$1" in
dir)
    printf '%s\n' "$LIVE_DIR"
    ;;

state)
    live_state
    ;;

list)
    cur=$(live_state)
    find "$LIVE_DIR" -maxdepth 1 -type f \
         \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
         | sort | while read -r v; do
        base=${v##*/}
        name=${base%.*}
        [ "$v" = "$cur" ] && act=yes || act=no
        # Постер отдаём, только если он уже готов: вытаскивать кадры из
        # десятков видео во время построения списка — это секунды ожидания,
        # их догоняет «warm».
        p="$THUMBS/$name.jpg"
        [ -f "$p" ] && [ ! "$v" -nt "$p" ] || p=""
        printf '%s|%s|%s|%s\n' "$name" "$p" "$act" "$v"
    done
    ;;

warm)
    find "$LIVE_DIR" -maxdepth 1 -type f \
         \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) \
         | while read -r v; do poster "$v" >/dev/null; done
    ;;

set)
    [ -z "$2" ] && exit 1
    vid=$(resolve "$2") || { echo "не нашёл видео: $2" >&2; exit 1; }

    pkill -x hyprpaper >/dev/null 2>&1
    pkill -x mpvpaper  >/dev/null 2>&1
    sleep 0.2

    # Опции mpv идут БЕЗ двойных дефисов: mpvpaper передаёт строку своему
    # парсеру, и «--loop-inf» до mpv не доходил — видео доигрывало до конца и
    # экран становился чёрным.
    #   loop-file=inf  — обои не должны кончаться
    #   keep-open=yes  — даже если что-то пойдёт не так, остаётся последний кадр,
    #                    а не чернота
    #   no-audio       — обои не звучат
    #   hwdec          — декодирование уезжает в видеокарту, где это возможно
    MPV_OPTS="loop-file=inf keep-open=yes no-audio hwdec=auto-safe vo=gpu"

    # По одному экземпляру на монитор, а не один на всё через «*».
    # Автопауза у mpvpaper считается на весь экземпляр: с общим на все выходы
    # полноэкранное окно на одном мониторе останавливало обои и на остальных.
    #
    # -p (и только он): mpv засыпает, когда обои закрыты. Флага -a MAX здесь
    # нет намеренно — он расширяет паузу на ЛЮБОЕ развёрнутое окно в системе,
    # а не на то, что закрывает сами обои.
    mons=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name')
    [ -n "$mons" ] || mons='*'
    for M in $mons; do
        mpvpaper -f -p -l background -o "$MPV_OPTS" "$M" "$vid" >/dev/null 2>&1
    done

    save_live "$vid"
    ;;

stop)
    pkill -x mpvpaper >/dev/null 2>&1
    save_live ""
    # возвращаем ту картинку, что была до живых обоев
    [ -x "$SWITCH" ] && "$SWITCH" --restore >/dev/null 2>&1
    ;;

*)
    echo "usage: live_wallpaper.sh dir|list|set <video>|stop|state|warm" >&2
    exit 1
    ;;
esac
