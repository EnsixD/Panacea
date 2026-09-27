#!/usr/bin/env bash
# Язык системы.
#
#   locale.sh get        — какой язык стоит сейчас: ru | en
#   locale.sh set ru|en  — сменить (нужен root, поэтому зовётся через pkexec)
#
# Язык оболочки живёт в её собственных настройках и меняется мгновенно. Здесь
# — язык всего остального: приложений, меню, системных сообщений. Он задаётся
# переменной LANG в /etc/locale.conf, а её читают при входе, поэтому смена
# доходит до приложений только после перезахода.
#
# LC_TIME трогать нельзя: он держит 24-часовой формат часов и не зависит от
# выбранного языка — на русском тоже нужны 00:02, а не 12:02 AM.
set -u

CONF=/etc/locale.conf
GEN=/etc/locale.gen

want_locale() {
    case "$1" in
        ru) echo "ru_RU.UTF-8" ;;
        *)  echo "en_US.UTF-8" ;;
    esac
}

cmd_get() {
    local cur=""
    [ -r "$CONF" ] && cur="$(grep -m1 '^LANG=' "$CONF" 2>/dev/null | cut -d= -f2)"
    [ -n "$cur" ] || cur="${LANG:-en_US.UTF-8}"
    case "$cur" in
        ru*) echo ru ;;
        *)   echo en ;;
    esac
}

cmd_set() {
    local loc; loc="$(want_locale "$1")"

    # Локали может не быть в системе: тогда переменная указывала бы в никуда,
    # и приложения молча откатились бы к английскому.
    if ! locale -a 2>/dev/null | grep -qiE "^${loc%.UTF-8}\.?utf-?8$"; then
        if [ -f "$GEN" ]; then
            sed -i "s/^#\s*${loc} UTF-8/${loc} UTF-8/" "$GEN" 2>/dev/null
            grep -q "^${loc} UTF-8" "$GEN" 2>/dev/null || echo "${loc} UTF-8" >> "$GEN"
            locale-gen >/dev/null 2>&1
        fi
    fi

    if grep -q '^LANG=' "$CONF" 2>/dev/null; then
        sed -i "s|^LANG=.*|LANG=${loc}|" "$CONF"
    else
        echo "LANG=${loc}" >> "$CONF"
    fi

    # Часы остаются 24-часовыми при любом языке.
    if grep -q '^LC_TIME=' "$CONF" 2>/dev/null; then
        sed -i "s|^LC_TIME=.*|LC_TIME=en_GB.UTF-8|" "$CONF"
    else
        echo "LC_TIME=en_GB.UTF-8" >> "$CONF"
    fi

    echo "$1"
}

case "${1:-}" in
    get) cmd_get ;;
    set) cmd_set "${2:-en}" ;;
    *)   echo "usage: locale.sh get|set <ru|en>" >&2; exit 1 ;;
esac
