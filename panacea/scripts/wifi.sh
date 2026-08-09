#!/bin/bash
# Помощник для Wi-Fi на iwd (в системе нет NetworkManager).
#
#   status            -> RADIO|SSID|QUALITY      (RADIO = on|off)
#   list              -> строки  connected|ssid|security|quality|known
#   scan              -> запускает поиск сетей
#   toggle            -> включает/выключает радио
#   connect SSID [PW] -> подключение (PW нужен только для незнакомых сетей)
#   forget SSID       -> забыть сеть

IFACE="${WIFI_IFACE:-wlan0}"

# iwctl раскрашивает вывод — убираем escape-последовательности
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

radio_state() {
    rfkill list wifi 2>/dev/null | grep -q 'Soft blocked: no' && echo on || echo off
}

current_ssid() {
    iw dev "$IFACE" link 2>/dev/null \
        | sed -n 's/.*SSID: //p' \
        | sed 's/\\x20/ /g; s/ *$//'
}

# уровень сигнала в dBm -> проценты
current_quality() {
    local d
    d=$(iw dev "$IFACE" link 2>/dev/null | sed -n 's/.*signal: \(-[0-9]*\).*/\1/p')
    [ -z "$d" ] && { echo 0; return; }
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

forget)
    [ -z "$2" ] && exit 1
    iwctl known-networks "$2" forget >/dev/null 2>&1
    ;;

*)
    echo "usage: wifi.sh status|list|scan|toggle|connect SSID [PW]|forget SSID" >&2
    exit 1
    ;;
esac
