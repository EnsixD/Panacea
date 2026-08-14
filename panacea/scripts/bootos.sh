#!/usr/bin/env bash
# Другие операционные системы на этой машине и разовая загрузка в них.
#
#   bootos.sh list        — список систем: id|название|вид
#   bootos.sh boot <id>   — следующая загрузка в эту систему, затем перезагрузка
#                           (нужен root, поэтому зовётся через pkexec)
#
# Разовая, а не постоянная: система, выбранная по умолчанию, не меняется.
# Один раз загрузились в Windows — следующая перезагрузка снова приведёт сюда.
# Иначе выбор из лаунчера молча переставлял бы загрузчик, и человек узнавал бы
# об этом через неделю.
#
# Систем может быть сколько угодно: список ничего не знает про Windows и не
# ограничен двумя пунктами. Откуда он берётся:
#
#   1. GRUB. Пункты, которые сделал os-prober, — это ровно «чужие системы»:
#      свои GRUB генерирует другими скриптами и метит иначе. Загрузка через
#      grub-reboot, штатный механизм одноразового выбора.
#   2. Если GRUB не стоит — записи EFI в NVRAM и BootNext. Работает с любым
#      загрузчиком, но имена там какие прошили, и мусора больше, поэтому
#      это запасной путь, а не основной.
set -u

GRUB_CFG=""
for c in /boot/grub/grub.cfg /boot/grub2/grub.cfg /boot/efi/EFI/*/grub.cfg; do
    [ -f "$c" ] && { GRUB_CFG="$c"; break; }
done

# Имя для человека, а не для загрузчика.
#
# os-prober и прошивка называют системы так, как записано у них внутри:
# «Windows Boot Manager (on /dev/nvme0n1p1)». Раздел выбирают не глазами, а
# «Boot Manager» — это про загрузчик, тогда как выбирают систему. Дистрибутивы
# при этом трогать нельзя: «Ubuntu 24.04 LTS» без версии станет хуже, а не
# лучше, поэтому обрезаем только заведомо служебные хвосты.
pretty_name() {
    printf '%s' "$1" \
        | sed 's/ (on \/dev\/[^)]*)//' \
        | sed 's/ *Boot Manager$//; s/ *Bootloader$//' \
        | sed 's/^ *//; s/ *$//'
}

grub_cmd() {
    for g in grub-reboot grub2-reboot; do
        command -v "$g" >/dev/null 2>&1 && { echo "$g"; return 0; }
    done
    return 1
}

# ------------------------------------------------------------------ список
list_grub() {
    [ -n "$GRUB_CFG" ] || return 1
    grub_cmd >/dev/null || return 1

    # Заголовок в кавычках и идентификатор osprober-* лежат в одной строке.
    # Вид берём из --class: он у os-prober проставлен по найденной системе.
    grep -oE "menuentry '[^']*'[^{]*osprober-[a-zA-Z0-9._-]*" "$GRUB_CFG" 2>/dev/null |
    while IFS= read -r line; do
        title=$(printf '%s' "$line" | sed -n "s/^menuentry '\([^']*\)'.*/\1/p")
        id=$(printf '%s' "$line" | grep -oE 'osprober-[a-zA-Z0-9._-]*')
        [ -n "$title" ] && [ -n "$id" ] || continue

        kind=other
        case "$line" in
            *--class\ windows*) kind=windows ;;
            *--class\ macosx*|*--class\ osx*) kind=mac ;;
            *--class\ gnu-linux*|*--class\ linux*) kind=linux ;;
        esac

        printf '%s|%s|%s\n' "$id" "$(pretty_name "$title")" "$kind"
    done
}

list_efi() {
    command -v efibootmgr >/dev/null 2>&1 || return 1
    local out; out="$(efibootmgr -v 2>/dev/null)" || return 1
    local current; current="$(printf '%s' "$out" | sed -n 's/^BootCurrent: *//p')"

    printf '%s\n' "$out" | grep -E '^Boot[0-9A-Fa-f]{4}\*' |
    while IFS= read -r line; do
        num=$(printf '%s' "$line" | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*.*/\1/p')
        [ "$num" = "$current" ] && continue          # это мы сами
        name=$(printf '%s' "$line" | sed -n 's/^Boot[0-9A-Fa-f]\{4\}\*[[:space:]]*//p' \
               | sed 's/\t.*//')

        # Съёмные носители и записи самого загрузчика — не системы.
        case "$name" in
            "UEFI: "*|"UEFI OS"|GRUB|grub|rEFInd|systemd-bootx64*) continue ;;
        esac
        case "$line" in *USB\(*) continue ;; esac
        [ -n "$name" ] || continue

        kind=other
        case "$line" in
            *bootmgfw.efi*|*Microsoft*) kind=windows ;;
            *Apple*|*System\\Library*)  kind=mac ;;
            *vmlinuz*|*linux*|*Linux*)  kind=linux ;;
        esac
        printf 'efi:%s|%s|%s\n' "$num" "$(pretty_name "$name")" "$kind"
    done
}

# ------------------------------------------------------------------ запуск
boot_into() {
    local id="${1:-}"
    [ -n "$id" ] || { echo "no id" >&2; return 1; }

    case "$id" in
        efi:*)
            command -v efibootmgr >/dev/null 2>&1 || { echo "no efibootmgr" >&2; return 1; }
            efibootmgr --bootnext "${id#efi:}" >/dev/null 2>&1 \
                || { echo "bootnext failed" >&2; return 1; }
            ;;
        *)
            local g; g="$(grub_cmd)" || { echo "no grub-reboot" >&2; return 1; }
            "$g" "$id" >/dev/null 2>&1 || { echo "grub-reboot failed" >&2; return 1; }
            ;;
    esac

    # Перезагружаемся отдельным шагом и только после того, как выбор
    # записался: если запись не удалась, машина остаётся здесь, а не уходит
    # в перезагрузку, чтобы вернуться туда же и без объяснений.
    systemctl reboot
}

case "${1:-list}" in
    list)
        out="$(list_grub)"
        [ -n "$out" ] || out="$(list_efi)"
        printf '%s' "$out" | grep -v '^$' || true
        ;;
    boot) boot_into "${2:-}" ;;
    *) echo "usage: bootos.sh list|boot <id>" >&2; exit 1 ;;
esac
