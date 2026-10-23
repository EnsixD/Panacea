#!/usr/bin/env bash
# Контрольные суммы установленных файлов — чтобы обновление отличало файл,
# который человек правил, от нетронутого.
#
#   manifest.sh write SRC    после установки: суммы ~/.config/<путь> для всех
#                            файлов, которые привёз репозиторий SRC
#   manifest.sh save SRC DIR перед обновлением: в DIR сложить всё, что человек
#                            поменял или добавил сам (список — DIR/.list)
#   manifest.sh restore DIR  после обновления: вернуть сложенное. Если
#                            файл в новой версии тоже изменился, свежий
#                            ложится рядом как <файл>.panacea-new
#
# Нетронутый файл обновление спокойно заменяет новым — иначе исправления
# в конфигах никогда бы до человека не доезжали.
set -u
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
MANIFEST="${XDG_STATE_HOME:-$HOME/.local/state}/panacea/manifest"
DIRS=(panacea hypr niri foot fish fastfetch)

# Что считать не «правкой человека», а производным или временным: эти файлы
# ведёт сама оболочка (или их сохраняет update.sh отдельным списком).
skip() {
    case "$1" in
        *.bak*|*.panacea-new|*/.git/*|*/__pycache__/*) return 0 ;;
        hypr/wallpaper/*|panacea/assets/*) return 0 ;;
        panacea/.version|panacea/VERSION|panacea/.whatsnew|panacea/.missingdeps|panacea/.obsoletedeps) return 0 ;;
        panacea/.keptedits|panacea/.vibrance|panacea/settings.json|panacea/clipboard_pins.json) return 0 ;;
        panacea/last_wifi_ssid|panacea/custom/*|panacea/scripts/custom/*) return 0 ;;
        hypr/lua/*_data.lua|hypr/*_data.conf|hypr/monitors.conf|hypr/shaders/vibrance.frag) return 0 ;;
        hypr/wallpaper.conf|hypr/hyprpaper.conf|hypr/custom/*|niri/custom/*) return 0 ;;
    esac
    return 1
}

case "${1:-}" in
write)
    src="${2:?}"
    mkdir -p "$(dirname "$MANIFEST")"
    tmp="$MANIFEST.tmp"
    : > "$tmp"
    for d in "${DIRS[@]}"; do
        [ -d "$src/$d" ] || continue
        (cd "$src" && find "$d" -type f) | while IFS= read -r rel; do
            skip "$rel" && continue
            [ -f "$CONF/$rel" ] || continue
            printf '%s  %s\n' "$(sha256sum < "$CONF/$rel" | cut -d' ' -f1)" "$rel"
        done >> "$tmp"
    done
    mv -f "$tmp" "$MANIFEST"
    ;;

save)
    src="${2:?}"; out="${3:?}"
    mkdir -p "$out"
    : > "$out/.list"
    declare -A known=()
    if [ -f "$MANIFEST" ]; then
        while read -r hash rel; do
            [ -n "$rel" ] || continue
            known["$rel"]="$hash"
        done < "$MANIFEST"
    fi
    for d in "${DIRS[@]}"; do
        [ -d "$CONF/$d" ] || continue
        (cd "$CONF" && find "$d" -type f) | while IFS= read -r rel; do
            skip "$rel" && continue
            if [ -n "${known[$rel]:-}" ]; then
                # из репозитория: сохраняем, только если правили
                [ "$(sha256sum < "$CONF/$rel" | cut -d' ' -f1)" = "${known[$rel]}" ] && continue
                kind=edited; old="${known[$rel]}"
            elif [ -e "$src/$rel" ]; then
                # сумм ещё нет (первое обновление) — судить не по чему
                continue
            else
                kind=added; old=-
            fi
            mkdir -p "$out/$(dirname "$rel")"
            cp -a "$CONF/$rel" "$out/$rel"
            printf '%s %s %s\n' "$kind" "$old" "$rel" >> "$out/.list"
        done
    done
    ;;

restore)
    out="${2:?}"
    [ -f "$out/.list" ] || exit 0
    while read -r kind old rel; do
        [ -n "$rel" ] && [ -e "$out/$rel" ] || continue
        mkdir -p "$(dirname "$CONF/$rel")"
        # свежая версия рядом — только если она и правда новая: иначе это
        # та же заводская, что человек уже поправил под себя
        if [ -f "$CONF/$rel" ] && ! cmp -s "$out/$rel" "$CONF/$rel" \
           && [ "$(sha256sum < "$CONF/$rel" | cut -d' ' -f1)" != "$old" ]; then
            mv -f "$CONF/$rel" "$CONF/$rel.panacea-new"
        fi
        cp -a "$out/$rel" "$CONF/$rel"
        echo "kept $rel"
    done < "$out/.list"
    ;;

*) echo "usage: manifest.sh write SRC | save SRC DIR | restore DIR" >&2; exit 1 ;;
esac
