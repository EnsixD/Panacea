#!/bin/bash
# Запись экрана для пилюли (wf-recorder).
#
#   start FPS DIR SYS MIC MIC_DEV -> начать
#       SYS/MIC — 0|1, писать ли звук системы и микрофон
#       MIC_DEV — имя источника pactl ("" = источник по умолчанию)
#   pause                         -> пауза/продолжить (SIGSTOP/SIGCONT)
#   stop                          -> закончить, печатает путь к файлу
#   status                        -> idle | rec|PID|СТАРТ|ПАУЗА|ФАЙЛ
#                                         | paused|PID|СТАРТ|ПАУЗА|ФАЙЛ
#   mics                          -> список микрофонов: имя|описание
#
# Пауза сделана остановкой процесса: своей паузы у wf-recorder нет.
# Система+микрофон одновременно — через временный null-sink, в который
# заворачиваются оба источника: wf-recorder умеет писать только одно
# устройство.

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/panacea"
STATE="$STATE_DIR/record.state"
mkdir -p "$STATE_DIR"

read_state() {
    PID=""; STARTED=""; PAUSED_AT=""; PAUSED_TOTAL=0; FILE=""; MODULES=""
    [ -f "$STATE" ] || return 1
    # shellcheck disable=SC1090
    . "$STATE"
    [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null
}

write_state() {
    cat > "$STATE" <<EOF
PID=$PID
STARTED=$STARTED
PAUSED_AT=$PAUSED_AT
PAUSED_TOTAL=$PAUSED_TOTAL
FILE="$FILE"
MODULES="$MODULES"
EOF
}

# монитор текущего вывода = «звук системы»
default_monitor() {
    local sink
    sink=$(pactl get-default-sink 2>/dev/null)
    [ -n "$sink" ] && printf '%s.monitor\n' "$sink"
}

default_mic() { pactl get-default-source 2>/dev/null; }

unload_modules() {
    local ids="$1"
    for id in $ids; do pactl unload-module "$id" 2>/dev/null; done
}

# Доводка готового файла.
#
# Мессенджеры (Telegram и не только) считают mp4 БЕЗ звуковой дорожки не видео,
# а анимацией, и показывают его как GIF: без звука, без плеера, зациклено.
# Поэтому если писали без звука — подшиваем тишину. Видео не перекодируется
# (-c:v copy), это быстро и без потери качества.
#
# Заодно moov-атом уезжает в начало (+faststart): без этого превью в чатах и
# перемотка появляются только после полной загрузки файла.
finalize() {
    f="$1"
    [ -s "$f" ] || return 0
    command -v ffmpeg >/dev/null 2>&1 || return 0

    has_audio=""
    if command -v ffprobe >/dev/null 2>&1; then
        has_audio=$(ffprobe -v error -select_streams a -show_entries stream=index \
                            -of csv=p=0 "$f" 2>/dev/null | head -1)
    fi

    tmp="${f%.mp4}.tmp.mp4"
    if [ -n "$has_audio" ]; then
        ffmpeg -y -v error -i "$f" -c copy -movflags +faststart "$tmp" 2>/dev/null
    else
        ffmpeg -y -v error -i "$f" \
               -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
               -shortest -c:v copy -c:a aac -b:a 96k \
               -movflags +faststart "$tmp" 2>/dev/null
    fi

    if [ -s "$tmp" ]; then mv -f "$tmp" "$f"; else rm -f "$tmp"; fi
}

case "$1" in
    start)
        if read_state; then echo "already" >&2; exit 1; fi

        FPS="${2:-60}"
        DIR="${3:-$HOME/Videos}"
        SYS="${4:-0}"
        MIC="${5:-0}"
        MIC_DEV="${6:-}"

        DIR="${DIR/#\~/$HOME}"
        mkdir -p "$DIR" || exit 1
        FILE="$DIR/panacea-$(date +%Y%m%d-%H%M%S).mp4"

        [ -z "$MIC_DEV" ] && MIC_DEV=$(default_mic)
        SYS_DEV=$(default_monitor)

        MODULES=""
        AUDIO_DEV=""

        if [ "$SYS" = "1" ] && [ "$MIC" = "1" ]; then
            # оба источника: сводим их в отдельный null-sink
            m=$(pactl load-module module-null-sink sink_name=panacea_mix \
                    sink_properties=device.description=PanaceaMix 2>/dev/null) || m=""
            if [ -n "$m" ]; then
                MODULES="$m"
                l1=$(pactl load-module module-loopback source="$SYS_DEV" \
                        sink=panacea_mix latency_msec=40 2>/dev/null) && MODULES="$MODULES $l1"
                l2=$(pactl load-module module-loopback source="$MIC_DEV" \
                        sink=panacea_mix latency_msec=40 2>/dev/null) && MODULES="$MODULES $l2"
                AUDIO_DEV="panacea_mix.monitor"
            else
                # микшер не поднялся — пишем хотя бы систему
                AUDIO_DEV="$SYS_DEV"
            fi
        elif [ "$SYS" = "1" ]; then
            AUDIO_DEV="$SYS_DEV"
        elif [ "$MIC" = "1" ]; then
            AUDIO_DEV="$MIC_DEV"
        fi

        args=(-f "$FILE" -r "$FPS" -c libx264 -p preset=veryfast -p crf=23)
        [ -n "$AUDIO_DEV" ] && args+=("--audio=$AUDIO_DEV")

        wf-recorder "${args[@]}" >"$STATE_DIR/record.log" 2>&1 &
        PID=$!
        sleep 0.4
        if ! kill -0 "$PID" 2>/dev/null; then
            unload_modules "$MODULES"
            echo "failed" >&2
            tail -3 "$STATE_DIR/record.log" >&2
            exit 1
        fi

        STARTED=$(date +%s)
        PAUSED_AT=""
        PAUSED_TOTAL=0
        write_state
        echo "$FILE"
        ;;

    pause)
        read_state || { echo "idle" >&2; exit 1; }
        if [ -n "$PAUSED_AT" ]; then
            kill -CONT "$PID"
            PAUSED_TOTAL=$(( PAUSED_TOTAL + $(date +%s) - PAUSED_AT ))
            PAUSED_AT=""
        else
            kill -STOP "$PID"
            PAUSED_AT=$(date +%s)
        fi
        write_state
        ;;

    stop)
        read_state || { echo "idle" >&2; exit 1; }
        [ -n "$PAUSED_AT" ] && kill -CONT "$PID"
        kill -INT "$PID" 2>/dev/null
        # ждём, пока допишется контейнер: иначе файл окажется битым
        for _ in $(seq 1 50); do
            kill -0 "$PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -0 "$PID" 2>/dev/null && kill -TERM "$PID" 2>/dev/null
        unload_modules "$MODULES"
        rm -f "$STATE"
        finalize "$FILE"
        echo "$FILE"
        ;;

    status)
        if read_state; then
            if [ -n "$PAUSED_AT" ]; then
                echo "paused|$PID|$STARTED|$(( PAUSED_TOTAL + $(date +%s) - PAUSED_AT ))|$FILE"
            else
                echo "rec|$PID|$STARTED|$PAUSED_TOTAL|$FILE"
            fi
        else
            # процесс умер сам (например, кончилось место) — чистим за ним
            if [ -f "$STATE" ]; then
                # shellcheck disable=SC1090
                . "$STATE"
                unload_modules "$MODULES"
                rm -f "$STATE"
            fi
            echo "idle"
        fi
        ;;

    mics)
        pactl -f json list sources 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for s in data:
    name = s.get("name", "")
    # мониторы выводов — это «звук системы», а не микрофоны
    if name.endswith(".monitor") or s.get("monitor_source_name"):
        continue
    if name.startswith("panacea_mix"):
        continue
    desc = (s.get("description") or name)
    print(f"{name}|{desc}")
'
        ;;

    *)
        echo "usage: record.sh start FPS DIR SYS MIC [MIC_DEV] | pause | stop | status | mics" >&2
        exit 1
        ;;
esac
