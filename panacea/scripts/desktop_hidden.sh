#!/bin/sh
# Печатает id приложений, которые на этом рабочем столе показывать не надо:
# OnlyShowIn без текущего стола, NotShowIn с ним, Hidden=true.
#
# Quickshell отдаёт эти записи наравне с остальными, а дистрибутивы вроде
# Linux Mint ставят по две копии одних и тех же программ — для Cinnamon и
# для KDE (kde4/mintbackup.desktop, mintupdate-kde.desktop…). Без этого
# фильтра в Launchpad каждая такая программа стояла дважды.
#
# id — путь файла внутри каталога applications со слешами, заменёнными на
# «-», как в спецификации: kde4/mintbackup.desktop -> kde4-mintbackup.
# Каталоги идут по приоритету, и решает первый файл с этим id: своя копия
# в ~/.local/share перекрывает системную, как и положено.

desk="${XDG_CURRENT_DESKTOP:-Hyprland}"
dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

IFS=:
for d in $dirs; do
    a="$d/applications"
    [ -d "$a" ] || continue
    find "$a" -name '*.desktop' 2>/dev/null | while IFS= read -r f; do
        awk -v desk="$desk" -v id="$(printf '%s' "${f#"$a"/}" | sed 's|/|-|g; s|\.desktop$||')" '
            BEGIN { n = split(desk, cur, ":"); hide = 0; inmain = 0 }
            /^\[/ { inmain = ($0 == "[Desktop Entry]"); next }
            !inmain { next }
            /^Hidden=true/ { hide = 1 }
            /^OnlyShowIn=/ {
                v = substr($0, 12); ok = 0
                for (i = 1; i <= n; i++) if (index(";" v, ";" cur[i] ";")) ok = 1
                if (!ok) hide = 1
            }
            /^NotShowIn=/ {
                v = substr($0, 11)
                for (i = 1; i <= n; i++) if (index(";" v, ";" cur[i] ";")) hide = 1
            }
            END { print id "\t" hide }
        ' "$f"
    done
done | awk -F'\t' '!seen[$1]++ && $2 == 1 { print $1 }'
