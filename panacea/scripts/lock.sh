#!/bin/bash
# Запуск экрана блокировки (lock.qml).
#
# Здесь же готовится фон: обои темы, ужатые под экран и закешированные.
# Сам QML читает путь из PANACEA_LOCK_BG.

DIR="$(dirname "$(readlink -f "$0")")"
QML="$DIR/../lock.qml"

# След последнего запуска. Блокировку зовут из панели, где не видно ни
# вывода, ни кода возврата: если она не сработала, разбираться иначе не по
# чему. Файл один и переписывается каждым запуском — это не журнал, а
# отметка «докуда дошли в прошлый раз».
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/panacea/lock.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null
step() { printf '%s %s\n' "$(date +%H:%M:%S)" "$1" >> "$LOG"; }
: > "$LOG" 2>/dev/null
step "запуск, PATH=$PATH"

# уже заблокировано — второй экземпляр не нужен
if pgrep -f "quickshell --path .*lock\.qml" >/dev/null; then
    step "уже заблокировано — выходим"
    exit 0
fi

wallpaper=$(grep -m1 '^\$wallpaper' "$HOME/.config/hypr/wallpaper.conf" 2>/dev/null \
            | cut -d= -f2- | sed 's/^ *//; s/ *$//')
wallpaper="${wallpaper/#\~/$HOME}"

if [ -n "$wallpaper" ] && [ "$wallpaper" != "black" ] && [ -f "$wallpaper" ]; then
    bg=$("$DIR/thumbs.sh" lockbg "$wallpaper" 2>/dev/null)
    [ -n "$bg" ] && export PANACEA_LOCK_BG="$bg"
fi
step "фон готов: ${PANACEA_LOCK_BG:-нет}"
command -v quickshell >/dev/null 2>&1 || step "quickshell не найден в PATH"

# Тот же threaded-цикл, что и у пилюли: с драйвером NVIDIA Qt сам выбирает
# «basic», а он крутит анимации от таймера в 16 мс — 60 кадров на любом
# мониторе. На экране блокировки это особенно заметно: там всё держится на
# плавности появления.
export QSG_RENDER_LOOP="${QSG_RENDER_LOOP:-threaded}"

step "запускаю $QML"
exec quickshell --path "$QML" 2>>"$LOG"
