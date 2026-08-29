#!/bin/bash
# Обёртка над voxtype для пилюли: запись голоса и превращение его в текст,
# который voxtype сам вставляет в активное поле (wtype). Здесь только запуск и
# остановка записи да индикатор в острове, чтобы было видно, что идёт.
#
#   voxtype.sh start   -> начать запись (удержание кнопки/клавиши)
#   voxtype.sh stop    -> закончить: voxtype расшифрует и напечатает текст
#   voxtype.sh toggle  -> один раз старт, второй — стоп
#   voxtype.sh available -> yes|no, установлен ли voxtype
#
# Само распознавание, модель и вставка текста — на стороне voxtype. Клавишу
# (правый Alt) он слушает своим evdev-хоткеем; эта обёртка нужна кнопке в
# быстрых настройках и любому, кто хочет показать индикатор.

# PATH при запуске из оболочки бывает урезан — добавляем обычные места.
PATH="$PATH:/usr/bin:/usr/local/bin:$HOME/.local/bin:/bin:/opt/bin"
export PATH

CFG="$HOME/.config/panacea"
ipc() { qs -c "$CFG" ipc call pill "$@" >/dev/null 2>&1; }

find_vox() {
    local p
    p=$(command -v voxtype 2>/dev/null) && { printf '%s\n' "$p"; return 0; }
    for p in /usr/bin/voxtype /usr/local/bin/voxtype "$HOME/.local/bin/voxtype"; do
        [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

case "${1:-}" in
    available)
        find_vox >/dev/null 2>&1 && echo yes || echo no
        ;;
    start)
        VOX=$(find_vox) || { ipc voxUnavailable; exit 1; }
        if "$VOX" record start >/dev/null 2>&1; then
            ipc voxListening
        else
            ipc voxUnavailable
            exit 1
        fi
        ;;
    stop)
        VOX=$(find_vox) || { ipc voxDone; exit 1; }
        # Пока voxtype расшифровывает и печатает — показываем «Расшифровываю…».
        ipc voxTranscribing
        "$VOX" record stop >/dev/null 2>&1
        STATE_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/voxtype/state"
        if [ -f "$STATE_FILE" ]; then
            for _ in $(seq 1 200); do
                s=$(cat "$STATE_FILE" 2>/dev/null)
                [ "$s" = "transcribing" ] || [ "$s" = "recording" ] || break
                sleep 0.05
            done
        fi
        ipc voxDone
        ;;
    toggle)
        VOX=$(find_vox) || { ipc voxUnavailable; exit 1; }
        "$VOX" record toggle >/dev/null 2>&1
        ;;
    *)
        echo "usage: voxtype.sh start|stop|toggle|available" >&2
        exit 1
        ;;
esac
