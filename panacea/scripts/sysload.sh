#!/bin/bash
# Загрузка машины одной строкой — для сводки в быстрых настройках и виджетов.
#
#   sysload.sh           ->  cpu|mem|gpu|tcpu|tgpu|disk
#   sysload.sh --fast    ->  |mem||||disk  (без задержки сна и nvidia-smi для виджетов рабочего стола)
#
# Проценты целыми числами, температуры в градусах Цельсия. Чего измерить не
# вышло, приходит пустым: панель тогда прячет эту строку, а не рисует ноль.
# Ноль здесь врёт слишком убедительно — «видеокарта простаивает» и «датчика
# нет» на глаз неразличимы.

fast=0
[ "$1" = "--fast" ] || [ "$1" = "--desktop" ] && fast=1

cpu=""
tcpu=""
gpu=""
tgpu=""

# ------------------------------------------------------------------- процессор
if [ "$fast" -eq 0 ]; then
    read -r _ a b c prev_idle rest < /proc/stat
    prev_total=$((a + b + c + prev_idle))
    for x in $rest; do prev_total=$((prev_total + x)); done

    sleep 0.3

    read -r _ a b c idle rest < /proc/stat
    total=$((a + b + c + idle))
    for x in $rest; do total=$((total + x)); done

    dt=$((total - prev_total))
    di=$((idle - prev_idle))
    [ "$dt" -gt 0 ] && cpu=$(( (dt - di) * 100 / dt ))
fi

# ---------------------------------------------------------------------- память
# MemAvailable, а не MemFree: ядро отдаёт под кеш всё, что не занято, и по
# MemFree любая машина в работе выглядит забитой под завязку.
mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2}
           END{ if (t > 0) printf "%d", (t - a) * 100 / t }' /proc/meminfo)

# ------------------------------------------------------------------------ диск
# Занятое место на корневом разделе (/) в процентах.
disk=$(df -k / 2>/dev/null | awk 'NR==2 {if ($2>0) printf "%d", $3*100/$2}')

# -------------------------------------------------------------- температура ЦП
if [ "$fast" -eq 0 ]; then
    for h in /sys/class/hwmon/hwmon*; do
        case "$(cat "$h/name" 2>/dev/null)" in
            k10temp|coretemp|zenpower|cpu_thermal|acpitz_cpu)
                v=$(cat "$h/temp1_input" 2>/dev/null)
                [ -n "$v" ] && tcpu=$((v / 1000))
                break
                ;;
        esac
    done

    # ------------------------------------------------------------------- видеокарта
    for d in /sys/class/drm/card*/device; do
        [ -r "$d/gpu_busy_percent" ] || continue
        gpu=$(cat "$d/gpu_busy_percent" 2>/dev/null)
        break
    done
    for h in /sys/class/hwmon/hwmon*; do
        case "$(cat "$h/name" 2>/dev/null)" in
            amdgpu|nouveau|radeon|i915|nvidia)
                v=$(cat "$h/temp1_input" 2>/dev/null)
                [ -n "$v" ] && tgpu=$((v / 1000))
                break
                ;;
        esac
    done

    # Проприетарный драйвер Nvidia в sysfs не выкладывает ни загрузку, ни
    # температуру — их знает только nvidia-smi. Зовём его лишь когда без него не
    # обойтись: он просыпается заметно дольше, чем читается файл.
    if [ -z "$gpu" ] || [ -z "$tgpu" ]; then
        if command -v nvidia-smi >/dev/null 2>&1; then
            line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
                              --format=csv,noheader,nounits 2>/dev/null | head -1)
            if [ -n "$line" ]; then
                [ -z "$gpu" ]  && gpu=$(echo "$line"  | cut -d, -f1 | tr -d ' ')
                [ -z "$tgpu" ] && tgpu=$(echo "$line" | cut -d, -f2 | tr -d ' ')
            fi
        fi
    fi
fi

printf '%s|%s|%s|%s|%s|%s\n' "$cpu" "$mem" "$gpu" "$tcpu" "$tgpu" "$disk"
