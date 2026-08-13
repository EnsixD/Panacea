#!/bin/bash
# Смена обоев — и только обоев.
#
#   switch_theme.sh --restore     вернуть последние обои (автозапуск)
#   switch_theme.sh <имя>         обои из ~/.config/hypr/wallpaper (без .jpg)
#   switch_theme.sh <путь>        любой файл
#
# Без аргументов ничего не спрашивает: выбор обоев живёт в самой пилюле
# (Super + Shift + T), и держать ради того же самого второе меню на tofi
# значило бы держать и tofi.
#
# Цвета здесь не участвуют: палитра одна и лежит в palette.conf, её
# раскладывает palette.sh. Так смена картинки больше не перекрашивает
# терминалы и не трогает ни один файл, который читает сам Hyprland, —
# раньше из-за этого рабочие столы перетряхивались на каждой теме.

WALL_DIR="$HOME/.config/hypr/wallpaper"
# Отдельный файл, а не theme.conf: его никто не подключает через source,
# поэтому Hyprland при смене обоев остаётся в покое.
STATE="$HOME/.config/hypr/wallpaper.conf"

# Путь к обоям: либо готовый файл, либо имя без расширения. Ищем по всему
# каталогу обоев, а не только в его корне: скачанные наборы лежат в
# подкаталогах (shell, custom), и раньше выбор такой картинки молча
# заканчивался ничем.
resolve() {
    local n="$1"
    n="${n/#\~/$HOME}"
    if [ -f "$n" ]; then printf '%s\n' "$n"; return 0; fi
    find "$WALL_DIR" -maxdepth 2 -type f \
         \( -iname "$n.jpg" -o -iname "$n.jpeg" -o -iname "$n.png" -o -iname "$n.webp" \) \
         -print -quit 2>/dev/null | grep . && return 0
    return 1
}

current() {
    grep -m1 '^\$wallpaper' "$STATE" 2>/dev/null \
        | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

if [ "$1" = "--restore" ]; then
    # последними стояли живые обои — отдаём их своему скрипту и выходим
    LIVE=$(grep -m1 '^\$live' "$STATE" 2>/dev/null | cut -d= -f2- | sed 's/^ *//; s/ *$//')
    LIVE="${LIVE/#\~/$HOME}"
    if [ -n "$LIVE" ] && [ -f "$LIVE" ]; then
        exec "$(dirname "$0")/live_wallpaper.sh" set "$LIVE"
    fi
    WALL=$(current)
    [ -n "$WALL" ] || WALL=$(ls "$WALL_DIR"/*.jpg "$WALL_DIR"/*.png 2>/dev/null | head -1)
elif [ -n "$1" ]; then
    WALL=$(resolve "$1")
else
    echo "usage: switch_theme.sh --restore | <имя> | <путь>" >&2
    exit 1
fi

WALL="${WALL/#\~/$HOME}"
[ -n "$WALL" ] && [ -f "$WALL" ] || { echo "не нашёл обои: $1" >&2; exit 1; }

# Живые обои и статичные — один и тот же фон, поэтому включение картинки
# выключает видео. Иначе mpvpaper остался бы крутиться под ней.
if grep -q '^\$live' "$STATE" 2>/dev/null || pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -x mpvpaper >/dev/null 2>&1
fi

# запоминаем выбор: отсюда его читают пилюля, экран блокировки и автозапуск
mkdir -p "$(dirname "$STATE")"
{
    printf '# Файл создаётся автоматически при смене обоев.\n'
    printf '# Hyprland его не подключает: смена картинки не должна трогать конфиг.\n'
    printf '$wallpaper = %s\n' "$WALL"
} > "$STATE"

# ------------------------------------------------------------- hyprpaper
# В 0.8 у hyprpaper сменился формат конфига: вместо пары preload/wallpaper
# теперь блок wallpaper { monitor, path, fit_mode }.
#
# Коварство в том, что на старый формат он не ругается — он его просто не
# видит: «Monitor eDP-1 has no target, no wp will be created». Картинка при
# этом ставилась, но только через IPC, то есть пока сидишь в системе. После
# перезагрузки hyprpaper поднимался с пустым конфигом, и стол оставался
# чёрным, пока обои не выберешь заново.
#
# Пустой monitor в новом формате означает «все экраны» — это заодно снимает
# зависимость от списка мониторов на момент записи: подключённый позже
# экран получит те же обои.
hyprpaper_new_format() {
    local v maj min
    v=$(hyprpaper --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$v" ] || return 1
    maj=${v%%.*}
    min=$(printf '%s' "$v" | cut -d. -f2)
    [ "$maj" -gt 0 ] || [ "$min" -ge 8 ]
}

{
    if hyprpaper_new_format; then
        printf 'wallpaper {\n'
        printf '    monitor =\n'
        printf '    path = %s\n' "$WALL"
        printf '    fit_mode = cover\n'
        printf '}\n'
    else
        printf 'preload = %s\n' "$WALL"
        # одна строка на каждый монитор: ",path" на этой версии не работает
        hyprctl monitors -j | jq -r '.[].name' | while read -r M; do
            printf 'wallpaper = %s,%s\n' "$M" "$WALL"
        done
    fi
    printf 'splash = false\nipc = on\n'
} > "$HOME/.config/hypr/hyprpaper.conf"

# setsid: скрипт зовут и из оболочки, и из автозапуска — hyprpaper не должен
# оставаться на нашем выводе и держать канал открытым после нашего выхода
pgrep -x hyprpaper >/dev/null || { setsid hyprpaper >/dev/null 2>&1 & sleep 1; }
hyprctl hyprpaper preload "$WALL" >/dev/null 2>&1
hyprctl monitors -j | jq -r '.[].name' | while read -r M; do
    hyprctl hyprpaper wallpaper "$M,$WALL" >/dev/null 2>&1
done

# --------------------------------------------------------- фон экрана входа
# Greeter работает от пользователя sddm и в ~/ заглянуть не может: домашний
# каталог закрыт. Кладём готовую размытую копию в общий каталог, который
# создал install.sh. Размываем заранее: QML-блюр на greeter'е стоит кадров.
SDDM_DIR=/var/lib/panacea
if [ -d "$SDDM_DIR" ] && [ -w "$SDDM_DIR" ] && command -v ffmpeg >/dev/null; then
    # уменьшение до 1280 перед блюром: и быстрее, и размытие мягче
    ffmpeg -y -loglevel error -i "$WALL" \
        -vf "scale=1280:-1,gblur=sigma=28,eq=saturation=0.9" \
        -frames:v 1 "$SDDM_DIR/sddm-bg.jpg" 2>/dev/null \
        && chmod 644 "$SDDM_DIR/sddm-bg.jpg"
fi
