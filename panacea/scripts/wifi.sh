#!/bin/bash
# Помощник для Wi-Fi: поддерживает NetworkManager (nmcli) и iwd (iwctl/iw).
#
#   status            -> RADIO|SSID|QUALITY      (RADIO = on|off)
#   list              -> строки  connected|ssid|security|quality|known
#   scan              -> запускает поиск сетей
#   toggle            -> включает/выключает радио
#   connect SSID [PW] -> подключение (PW нужен только для незнакомых сетей)
#   disconnect        -> отключиться от текущей сети
#   forget SSID       -> забыть сеть (и отключиться, если она сейчас активна)

use_nm() {
    command -v nmcli >/dev/null 2>&1 && nmcli general status >/dev/null 2>&1
}

iface_list() {
    [ -n "${WIFI_IFACE:-}" ] && { printf '%s\n' "$WIFI_IFACE"; return; }
    local d n
    for d in /sys/class/net/*; do
        [ -d "$d/wireless" ] || [ -d "$d/phy80211" ] || continue
        n=$(basename "$d")
        printf '%s\n' "$n"
    done
}

active_iface() {
    if use_nm; then
        local nm_dev
        nm_dev=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')
        if [ -n "$nm_dev" ]; then
            printf '%s' "$nm_dev"
            return
        fi
    fi
    local i
    for i in $(iface_list); do
        [ -n "$(ssid_on "$i")" ] && { printf '%s' "$i"; return; }
    done
    iface_list | head -1
}

# iwctl раскрашивает вывод — убираем escape-последовательности
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

radio_state() {
    if use_nm; then
        local r
        r=$(nmcli -t -f WIFI general 2>/dev/null)
        [ "$r" = "enabled" ] && echo on || echo off
    else
        rfkill list wifi 2>/dev/null | grep -q 'Soft blocked: no' && echo on || echo off
    fi
}

ssid_on() {
    local i="$1" out

    if use_nm; then
        out=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1 ~ /^(\*|yes)$/ { print $2; exit }')
        if [ -n "$out" ]; then
            printf '%b' "$out"
            return
        fi
    fi

    out=$(iw dev "$i" link 2>/dev/null | sed -n 's/.*SSID: //p' | sed 's/ *$//')
    if [ -n "$out" ]; then
        printf '%b' "$out"
        return
    fi

    out=$(iwctl station "$i" show 2>/dev/null | strip \
          | sed -n 's/.*Connected network[[:space:]]*//p' | sed 's/ *$//')
    if [ -n "$out" ]; then
        printf '%b' "$out"
        return
    fi

    out=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null \
          | sed -n 's/^yes://p' | head -1)
    printf '%b' "$out"
}

IFACE="$(active_iface)"
IFACE="${IFACE:-wlan0}"

current_ssid() { ssid_on "$IFACE"; }

current_quality() {
    if use_nm; then
        local q
        q=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1 ~ /^(\*|yes)$/ { print $2; exit }')
        if [ -n "$q" ] && [ "$q" -gt 0 ] 2>/dev/null; then
            echo "$q"
            return
        fi
    fi
    local d
    d=$(iw dev "$IFACE" link 2>/dev/null | sed -n 's/.*signal: \(-[0-9]*\).*/\1/p')
    if [ -z "$d" ]; then
        d=$(awk -v i="$IFACE:" '$1==i {gsub(/\./,"",$3); print $3; exit}' \
            /proc/net/wireless 2>/dev/null)
        [ -n "$d" ] && [ "$d" -gt 0 ] 2>/dev/null && { echo "$d"; return; }
        echo 0; return
    fi
    awk -v d="$d" 'BEGIN{q=2*(d+100); if(q>100)q=100; if(q<0)q=0; print int(q)}'
}

known_iwd() {
    iwctl known-networks list 2>/dev/null | strip \
        | awk 'NR>4 && NF { sub(/^[[:space:]]+/,"");
               if (match($0, /[[:space:]][[:space:]]+(psk|open|8021x|wep)/)) {
                   print substr($0, 1, RSTART-1)
               } }' \
        | sed 's/[[:space:]]*$//'
}

known_networks() {
    local list=""
    if use_nm; then
        local nm_k
        nm_k=$(nmcli -t -f TYPE,802-11-wireless.ssid,NAME connection show 2>/dev/null | awk -F: '
            $1 ~ /802-11-wireless|wifi/ {
                if ($2 != "" && $2 != "--") print $2;
                else if ($3 != "") print $3;
            }
        ')
        [ -n "$nm_k" ] && list="$nm_k"
    fi
    if command -v iwctl >/dev/null 2>&1; then
        local iwd_k
        iwd_k=$(known_iwd)
        if [ -n "$iwd_k" ]; then
            [ -n "$list" ] && list=$(printf '%s\n%s' "$list" "$iwd_k") || list="$iwd_k"
        fi
    fi
    printf '%s\n' "$list" | sed '/^[[:space:]]*$/d' | sort -u
}

find_available_known() {
    local known="$(known_networks)"
    [ -z "$known" ] && return

    if use_nm; then
        nmcli -t -f SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -v known="$known" -F: '
            BEGIN {
                n = split(known, karr, "\n")
                for (i = 1; i <= n; i++) if (karr[i] != "") isKnown[karr[i]] = 1
            }
            {
                s = $1; q = int($2)
                if (s == "" || s == "--" || !isKnown[s]) next
                if (!(s in best_q) || q > best_q[s]) {
                    best_q[s] = q
                }
            }
            END {
                for (s in best_q) {
                    printf "%03d\t%s\n", best_q[s], s
                }
            }
        ' | sort -rn | cut -f2-
    else
        iwctl station "$IFACE" get-networks 2>/dev/null | strip | awk -v known="$known" '
            BEGIN {
                n = split(known, arr, "\n")
                for (i = 1; i <= n; i++) if (arr[i] != "") isKnown[arr[i]] = 1
            }
            {
                line = $0
                sub(/^[[:space:]]*>[[:space:]]*/, "", line)
                sub(/^[[:space:]]*/, "", line)
                if (match(line, /[[:space:]][[:space:]]+(psk|open|8021x|wep)[[:space:]]+\*+[[:space:]]*$/)) {
                    rest = substr(line, RSTART)
                    name = substr(line, 1, RSTART - 1)
                    split(rest, a, /[[:space:]]+/)
                    stars = a[3]
                    gsub(/[[:space:]]+$/, "", name)
                    quality = length(stars) * 25
                    if (isKnown[name]) {
                        if (!(name in best_q) || quality > best_q[name]) {
                            best_q[name] = quality
                        }
                    }
                }
            }
            END {
                for (name in best_q) {
                    printf "%03d\t%s\n", best_q[name], name
                }
            }
        ' | sort -rn | cut -f2-
    fi
}

autoconnect() {
    local last_file="${XDG_CONFIG_HOME:-$HOME/.config}/panacea/last_wifi_ssid"
    local last_net=""
    [ -f "$last_file" ] && last_net=$(cat "$last_file" 2>/dev/null)

    if use_nm; then
        if [ -n "$last_net" ] && nmcli -t -f SSID dev wifi list --rescan no 2>/dev/null | grep -Fxq "$last_net"; then
            nmcli connection up id "$last_net" >/dev/null 2>&1 && return 0
        fi
        while IFS= read -r net; do
            [ -z "$net" ] && continue
            if nmcli connection up id "$net" >/dev/null 2>&1; then
                printf '%s' "$net" > "$last_file" 2>/dev/null
                return 0
            fi
        done < <(find_available_known)
        nmcli dev wifi rescan >/dev/null 2>&1 || true
    else
        local cur_iface="$(active_iface)"
        cur_iface="${cur_iface:-wlan0}"

        if [ -n "$(ssid_on "$cur_iface")" ]; then
            return 0
        fi

        # Scan to refresh available networks
        iwctl station "$cur_iface" scan >/dev/null 2>&1
        sleep 0.5

        # 1. Try last connected network first if available
        if [ -n "$last_net" ]; then
            if iwctl station "$cur_iface" connect "$last_net" >/dev/null 2>&1; then
                return 0
            fi
        fi

        # 2. If last_net is not available or failed to connect, try other available known networks
        while IFS= read -r net; do
            [ -z "$net" ] && continue
            [ "$net" = "$last_net" ] && continue
            if iwctl station "$cur_iface" connect "$net" >/dev/null 2>&1; then
                printf '%s' "$net" > "$last_file" 2>/dev/null
                return 0
            fi
        done < <(find_available_known)

        # 3. If still not connected, wait briefly and retry in case scan was still in progress
        if [ -z "$(ssid_on "$cur_iface")" ]; then
            sleep 0.6
            while IFS= read -r net; do
                [ -z "$net" ] && continue
                if iwctl station "$cur_iface" connect "$net" >/dev/null 2>&1; then
                    printf '%s' "$net" > "$last_file" 2>/dev/null
                    return 0
                fi
            done < <(find_available_known)
        fi

        iwctl station "$cur_iface" scan >/dev/null 2>&1
    fi
}

case "$1" in
status)
    last_file="${XDG_CONFIG_HOME:-$HOME/.config}/panacea/last_wifi_ssid"
    cur_s="$(current_ssid)"
    [ -n "$cur_s" ] && printf '%s' "$cur_s" > "$last_file" 2>/dev/null
    echo "$(radio_state)|$cur_s|$(current_quality)"
    ;;

scan)
    if use_nm; then
        nmcli dev wifi rescan >/dev/null 2>&1 || true
    else
        iwctl station "$IFACE" scan >/dev/null 2>&1
    fi
    ;;

list)
    KNOWN=$(known_networks)
    CUR_SSID="$(current_ssid)"
    if use_nm; then
        nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -v known="$KNOWN" -v cur_ssid="$CUR_SSID" '
        BEGIN {
            n = split(known, karr, "\n")
            for (i = 1; i <= n; i++) if (karr[i] != "") isKnown[karr[i]] = 1
            count = 0
        }
        {
            line = $0
            gsub(/\\:/, "\001", line)
            split(line, f, ":")
            in_use = f[1]
            ssid = f[2]
            sec = f[3]
            sig = f[4]
            gsub(/\001/, ":", ssid)
            if (ssid == "" || ssid == "--") next

            conn = (in_use == "*" || ssid == cur_ssid) ? "yes" : "no"
            quality = int(sig)
            sec_type = (sec == "" || sec == "--") ? "open" : "psk"

            if (!(ssid in seen) || conn == "yes" || quality > best_q[ssid]) {
                if (!(ssid in seen)) {
                    order[count++] = ssid
                }
                seen[ssid] = 1
                best_conn[ssid] = (best_conn[ssid] == "yes" || conn == "yes") ? "yes" : "no"
                best_q[ssid] = quality
                best_sec[ssid] = sec_type
            }
        }
        END {
            for (i = 0; i < count; i++) {
                s = order[i]
                k = (isKnown[s] || s == cur_ssid) ? "yes" : "no"
                print best_conn[s] "|" s "|" best_sec[s] "|" best_q[s] "|" k
            }
        }'
    else
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
    fi
    ;;

toggle)
    if use_nm; then
        if [ "$(radio_state)" = "on" ]; then
            nmcli radio wifi off >/dev/null 2>&1
        else
            nmcli radio wifi on >/dev/null 2>&1
            ( sleep 0.3 && autoconnect ) &
        fi
    else
        if [ "$(radio_state)" = "on" ]; then
            rfkill block wifi
        else
            rfkill unblock wifi
            cur_iface="$(active_iface)"
            cur_iface="${cur_iface:-wlan0}"
            if command -v iwctl >/dev/null 2>&1; then
                iwctl device "$cur_iface" set-property Powered on >/dev/null 2>&1 || true
                ( sleep 0.3 && autoconnect ) &
            fi
        fi
    fi
    ;;

autoconnect)
    autoconnect
    ;;

connect)
    SSID="$2"; PW="$3"
    [ -z "$SSID" ] && exit 1
    last_file="${XDG_CONFIG_HOME:-$HOME/.config}/panacea/last_wifi_ssid"
    printf '%s' "$SSID" > "$last_file" 2>/dev/null
    if use_nm; then
        if [ -n "$PW" ]; then
            nmcli dev wifi connect "$SSID" password "$PW" >/dev/null 2>&1
            rc=$?
        else
            if nmcli connection show "$SSID" >/dev/null 2>&1; then
                nmcli connection up id "$SSID" >/dev/null 2>&1
                rc=$?
            else
                nmcli dev wifi connect "$SSID" >/dev/null 2>&1
                rc=$?
            fi
        fi
        exit $rc
    else
        if [ -n "$PW" ]; then
            iwctl --passphrase "$PW" station "$IFACE" connect "$SSID" >/dev/null 2>&1
        else
            iwctl station "$IFACE" connect "$SSID" >/dev/null 2>&1
        fi
        # Ждём установления связи, чтобы вызывающий сразу увидел новую сеть
        for _ in $(seq 1 12); do
            sleep 0.5
            [ "$(current_ssid)" = "$SSID" ] && exit 0
        done
        exit $?
    fi
    ;;

disconnect)
    if use_nm; then
        nmcli dev disconnect "$IFACE" >/dev/null 2>&1 || true
    else
        iwctl station "$IFACE" disconnect >/dev/null 2>&1
    fi
    ;;

forget)
    [ -z "$2" ] && exit 1
    if use_nm; then
        [ "$2" = "$(current_ssid)" ] && nmcli dev disconnect "$IFACE" >/dev/null 2>&1
        nmcli connection delete id "$2" >/dev/null 2>&1 || true
    else
        [ "$2" = "$(current_ssid)" ] && iwctl station "$IFACE" disconnect >/dev/null 2>&1
        iwctl known-networks "$2" forget >/dev/null 2>&1
    fi
    ;;

*)
    echo "usage: wifi.sh status|list|scan|toggle|connect SSID [PW]|disconnect|forget SSID" >&2
    exit 1
    ;;
esac
