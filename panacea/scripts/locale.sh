#!/usr/bin/env bash
# System locale selection.
#
#   locale.sh get        — current system locale
#   locale.sh list       — available UTF-8 locales
#   locale.sh set CODE   — select a locale (called through pkexec)
#
# The shell reads its own language setting immediately. Applications and system
# messages read LANG from /etc/locale.conf at login, so they change next login.
#
# The clock format is controlled by the shell setting; date names should use
# the selected locale, including outside Panacea.
set -u

CONF=/etc/locale.conf
GEN=/etc/locale.gen

want_locale() {
    local code="$1" loc
    case "$code" in
        en) code=en_US ;;
        ru) code=ru_RU ;;
        tr) code=tr_TR ;;
    esac
    [[ "$code" =~ ^[a-z]{2,3}_[A-Z]{2}$ ]] || return 1
    loc="${code}.UTF-8"
    if [ -r "$GEN" ] && ! grep -Fqx "$loc UTF-8" "$GEN" && ! grep -Fqx "# $loc UTF-8" "$GEN"; then
        return 1
    fi
    printf '%s\n' "$loc"
}

cmd_list() {
    printf 'en|English\nru|Русский\ntr|Türkçe\n'
    if [ -r "$GEN" ]; then
        awk '$1 ~ /^#?[a-z]{2,3}_[A-Z]{2}\.UTF-8$/ && $2 == "UTF-8" {
            sub(/^#/, "", $1); sub(/\.UTF-8$/, "", $1); print $1 "|" $1
        }' "$GEN" | sort -u
    else
        locale -a | sed -nE 's/^([a-z]{2,3}_[A-Z]{2})\.(utf8|UTF-8)$/\1|\1/p' | sort -u
    fi
}

cmd_get() {
    local cur=""
    [ -r "$CONF" ] && cur="$(grep -m1 '^LANG=' "$CONF" 2>/dev/null | cut -d= -f2)"
    [ -n "$cur" ] || cur="${LANG:-en_US.UTF-8}"
    cur="${cur%%.*}"
    case "$cur" in
        en_US) echo en ;;
        ru_RU) echo ru ;;
        tr_TR) echo tr ;;
        *) printf '%s\n' "$cur" ;;
    esac
}

cmd_set() {
    local loc; loc="$(want_locale "$1")" || { echo "Unsupported locale: $1" >&2; return 1; }

    # Локали может не быть в системе: тогда переменная указывала бы в никуда,
    # и приложения молча откатились бы к английскому.
    if ! locale -a 2>/dev/null | grep -qiE "^${loc%.UTF-8}\.?utf-?8$"; then
        if [ -f "$GEN" ]; then
            sed -i "s/^#\s*${loc} UTF-8/${loc} UTF-8/" "$GEN" 2>/dev/null
            grep -q "^${loc} UTF-8" "$GEN" 2>/dev/null || echo "${loc} UTF-8" >> "$GEN"
            locale-gen >/dev/null 2>&1 || return 1
        fi
    fi
    locale -a 2>/dev/null | grep -qiE "^${loc%.UTF-8}\.?utf-?8$" || return 1

    if grep -q '^LANG=' "$CONF" 2>/dev/null; then
        sed -i "s|^LANG=.*|LANG=${loc}|" "$CONF"
    else
        echo "LANG=${loc}" >> "$CONF"
    fi

    if grep -q '^LC_TIME=' "$CONF" 2>/dev/null; then
        sed -i "s|^LC_TIME=.*|LC_TIME=${loc}|" "$CONF"
    else
        echo "LC_TIME=${loc}" >> "$CONF"
    fi

    echo "$1"
}

case "${1:-}" in
    get) cmd_get ;;
    list) cmd_list ;;
    set) cmd_set "${2:-en}" ;;
    *)   echo "usage: locale.sh get|list|set <locale>" >&2; exit 1 ;;
esac
