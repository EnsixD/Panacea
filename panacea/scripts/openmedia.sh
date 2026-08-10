#!/bin/bash
# Открыть картинку/видео в медиаплеере пилюли.
#
# Ставится обработчиком image/* и video/* (см. panacea-media.desktop), поэтому
# «Открыть» в браузере и `xdg-open file.png` ведут не в браузер, а сюда.
# Аргумент может прийти как путь или как file:// URL.

f="$1"
case "$f" in
    file://*)
        # снимаем схему и раскодируем %xx
        f="${f#file://}"
        f=$(printf '%b' "${f//%/\\x}")
        ;;
esac

[ -n "$f" ] || exit 1
exec qs -p "$HOME/.config/panacea" ipc call pill media "$f"
