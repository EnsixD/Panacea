#!/bin/bash
# Помощник для Wi-Fi на iwd (в системе нет NetworkManager).
#
#   status            -> RADIO|SSID|QUALITY      (RADIO = on|off)
#   list              -> строки  connected|ssid|security|quality|known
#   scan              -> запускает поиск сетей
#   toggle            -> включает/выключает радио
#   connect SSID [PW] -> подключение (PW нужен только для незнакомых сетей)
#   disconnect        -> отключиться от текущей сети
#   forget SSID       -> забыть сеть (и отключиться, если она сейчас активна)

# Все беспроводные интерфейсы машины. Имя может быть любым: wlan0 там, где
# ядро их не переименовывает, wlp2s0 и подобное — почти везде ещё, а на
# машине с двумя адаптерами их и вовсе несколько. Список берём из sysfs:
# каталог wireless есть ровно у беспроводных, и для этого не нужен ни iw,
# ни права.
iface_list() {
    [ -n "${WIFI_IFACE:-}" ] && { printf '%s\n' "$WIFI_IFACE"; return; }
    local d n
    for d in /sys/class/net/*; do
        [ -d "$d/wireless" ] || continue
        n=$(basename "$d")
        printf '%s\n' "$n"
    done
}

# Тот, что сейчас связан; если связи нет ни у одного — первый по списку.
# Спрашивать «какой интерфейс» бессмысленно без ответа «а что на нём»:
# у ноутбука с внешним свистком угадывание по имени промахивается.
active_iface() {
    local i
    for i in $(iface_list); do
        [ -n "$(ssid_on "$i")" ] && { printf '%s' "$i"; return; }
    done
    iface_list | head -1
}

# iwctl раскрашивает вывод — убираем escape-последовательности
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

radio_state() {
    rfkill list wifi 2>/dev/null | grep -q 'Soft blocked: no' && echo on || echo off
}

# Имя сети на конкретном интерфейсе. Спрашиваем по очереди у трёх источников:
# они дают один и тот же ответ, но есть не везде. `iw` идёт первым — он читает
# состояние прямо у ядра и не зависит от того, кто именно управляет сетью;
# дальше iwd и NetworkManager, каждый знает только про себя.
#
# Порядок важен и тем, что `iw` отвечает сразу после установления связи, тогда
# как остальные обновляют своё состояние с задержкой — из-за неё имя сети
# появлялось только после ручного сканирования.
ssid_on() {
    local i="$1" out

    out=$(iw dev "$i" link 2>/dev/null | sed -n 's/.*SSID: //p' | sed 's/ *$//')
    [ -n "$out" ] && { printf '%s' "$out"; return; }

    out=$(iwctl station "$i" show 2>/dev/null | strip \
          | sed -n 's/.*Connected network[[:space:]]*//p' | sed 's/ *$//')
    [ -n "$out" ] && { printf '%s' "$out"; return; }

    out=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null \
          | sed -n 's/^yes://p' | head -1)
    printf '%s' "$out"
}

# Интерфейс выбираем здесь, а не выше: active_iface спрашивает ssid_on, и
# та должна быть уже объявлена.
IFACE="$(active_iface)"
IFACE="${IFACE:-wlan0}"

current_ssid() { ssid_on "$IFACE"; }

# уровень сигнала в dBm -> проценты
current_quality() {
    local d
    d=$(iw dev "$IFACE" link 2>/dev/null | sed -n 's/.*signal: \(-[0-9]*\).*/\1/p')
    if [ -z "$d" ]; then
        # без iw остаётся то, что записало ядро: третья колонка /proc — это
        # качество связи по шкале драйвера, ноль там означает «нет данных»
        d=$(awk -v i="$IFACE:" '$1==i {gsub(/\./,"",$3); print $3; exit}' \
            /proc/net/wireless 2>/dev/null)
        [ -n "$d" ] && [ "$d" -gt 0 ] 2>/dev/null && { echo "$d"; return; }
        echo 0; return
    fi
    awk -v d="$d" 'BEGIN{q=2*(d+100); if(q>100)q=100; if(q<0)q=0; print int(q)}'
}

known_networks() {
    iwctl known-networks list 2>/dev/null | strip \
        | awk 'NR>4 && NF { sub(/^[[:space:]]+/,"");
               if (match($0, /[[:space:]][[:space:]]+(psk|open|8021x|wep)/)) {
                   print substr($0, 1, RSTART-1)
               } }' \
        | sed 's/[[:space:]]*$//'
}

case "$1" in
status)
    echo "$(radio_state)|$(current_ssid)|$(current_quality)"
    ;;

scan)
    iwctl station "$IFACE" scan >/dev/null 2>&1
    ;;

list)
    KNOWN=$(known_networks)
    iwctl station "$IFACE" get-networks 2>/dev/null | strip | awk -v known="$KNOWN" '
    BEGIN {
        n = split(known, arr, "\n")
        for (i = 1; i <= n; i++) if (arr[i] != "") isKnown[arr[i]] = 1
    }
    {
        connected = "no"; line = $0
        if (line ~ /^[[:space:]]*>/) {
            connected = "yes"
            sub(/^[[:space:]]*>[[:space:]]*/, "", line)
        } else {
            sub(/^[[:space:]]*/, "", line)
        }
        # строка сети: имя, затем защита и звёздочки сигнала
        if (match(line, /[[:space:]][[:space:]]+(psk|open|8021x|wep)[[:space:]]+\*+[[:space:]]*$/)) {
            rest = substr(line, RSTART)
            name = substr(line, 1, RSTART - 1)
            split(rest, a, /[[:space:]]+/)
            sec = a[2]; stars = a[3]
            gsub(/[[:space:]]+$/, "", name)
            # 1..4 звезды -> 25..100 %
            quality = length(stars) * 25
            print connected "|" name "|" sec "|" quality "|" (isKnown[name] ? "yes" : "no")
        }
    }'
    ;;

toggle)
    if [ "$(radio_state)" = "on" ]; then rfkill block wifi; else rfkill unblock wifi; fi
    ;;

connect)
    SSID="$2"; PW="$3"
    [ -z "$SSID" ] && exit 1
    if [ -n "$PW" ]; then
        iwctl --passphrase "$PW" station "$IFACE" connect "$SSID" >/dev/null 2>&1
    else
        iwctl station "$IFACE" connect "$SSID" >/dev/null 2>&1
    fi
    # 0 = успех; вызывающий может перечитать status
    exit $?
    ;;

disconnect)
    iwctl station "$IFACE" disconnect >/dev/null 2>&1
    ;;

forget)
    [ -z "$2" ] && exit 1
    # Сначала отключаемся, если забываем ту сеть, в которой сидим: иначе
    # соединение остаётся жить, а сеть уже не сохранена — на следующем
    # обрыве связь просто пропадёт без объяснения.
    [ "$2" = "$(current_ssid)" ] && iwctl station "$IFACE" disconnect >/dev/null 2>&1
    iwctl known-networks "$2" forget >/dev/null 2>&1
    ;;

*)
    echo "usage: wifi.sh status|list|scan|toggle|connect SSID [PW]|disconnect|forget SSID" >&2
    exit 1
    ;;
esac
