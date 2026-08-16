#!/bin/bash
# Загрузка машины одной строкой — для сводки в быстрых настройках.
#
#   sysload.sh  ->  cpu|mem|gpu|tcpu|tgpu
#
# Проценты целыми числами, температуры в градусах Цельсия. Чего измерить не
# вышло, приходит пустым: панель тогда прячет эту строку, а не рисует ноль.
# Ноль здесь врёт слишком убедительно — «видеокарта простаивает» и «датчика
# нет» на глаз неразличимы.
#
# Всё считается одним запуском, а не пятью: панель опрашивает раз в две
# секунды, и пять процессов на опрос стоили бы дороже самих данных.

# ------------------------------------------------------------------- процессор
# Мгновенной загрузки в /proc/stat нет — есть счётчики с момента загрузки.
# Поэтому берём два замера и делим приращение занятого времени на общее.
# loadavg тут не годится: это очередь на процессор за минуту, а не проценты,
# и на восьми ядрах его значение с процентами не совпадает вовсе.
read -r _ a b c prev_idle rest < /proc/stat
prev_total=$((a + b + c + prev_idle))
for x in $rest; do prev_total=$((prev_total + x)); done

# Пауза короткая: она целиком уходит в задержку ответа панели, а разрешения
# в треть секунды для полоски нагрузки хватает с избытком.
sleep 0.3

read -r _ a b c idle rest < /proc/stat
total=$((a + b + c + idle))
for x in $rest; do total=$((total + x)); done

dt=$((total - prev_total))
di=$((idle - prev_idle))
cpu=""
[ "$dt" -gt 0 ] && cpu=$(( (dt - di) * 100 / dt ))

# ---------------------------------------------------------------------- память
# MemAvailable, а не MemFree: ядро отдаёт под кеш всё, что не занято, и по
# MemFree любая машина в работе выглядит забитой под завязку.
mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2}
           END{ if (t > 0) printf "%d", (t - a) * 100 / t }' /proc/meminfo)

# -------------------------------------------------------------- температура ЦП
tcpu=""
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
# Сначала sysfs: у amdgpu и i915 загрузка лежит прямо в файле, и читать его
# в разы дешевле, чем звать чужую программу.
gpu=""
tgpu=""
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

printf '%s|%s|%s|%s|%s\n' "$cpu" "$mem" "$gpu" "$tcpu" "$tgpu"
