#!/bin/bash
# Бэкенд проводника пилюли.
#
#   list DIR              -> строки  тип|имя|размер|мтайм|mime
#                            тип: d (каталог) | f (файл)
#   apps PATH             -> чем можно открыть: desktop-файл|Название|Иконка
#                            первым идёт приложение по умолчанию
#   open PATH [DESKTOP]   -> открыть (без DESKTOP — приложением по умолчанию)
#   mkdir DIR NAME        -> создать папку
#   rename PATH NEWNAME   -> переименовать
#   trash PATH            -> в корзину (обратимо, в отличие от rm)
#   places                -> закладки: ключ|путь|подпись
#   copy DST SRC...       -> копировать в каталог
#   move DST SRC...       -> перенести в каталог
#
# copy и move печатают в stdout строки «PROGRESS <проценты>»: пилюля рисует
# по ним полоску. Копирование гигабайтов иначе выглядит как зависание —
# файл не появляется, и понять, идёт работа или нет, нельзя.

py() { python3 "$@"; }

# ---------------------------------------------------------------- прогресс
# Ни cp, ни mv не умеют сообщать, сколько уже сделано, поэтому смотрим со
# стороны: раз в четверть секунды меряем, насколько выросли цели. rsync
# показал бы то же самое сам, но он не входит в base, а тянуть зависимость
# ради полоски не хочется.
#
# Меряем именно цели, а не каталог назначения целиком: назначением может
# быть домашняя папка, и du по ней каждые 250 мс стоил бы дороже самого
# копирования.
PROGRESS_PID=""

progress_start() {   # $1 — суммарный размер источников, дальше пути целей
    local total=$1; shift
    [ "$total" -gt 0 ] 2>/dev/null || return 0
    local targets=("$@")
    (
        while :; do
            local cur
            cur=$(du -sbc "${targets[@]}" 2>/dev/null | tail -1 | cut -f1)
            if [ -n "$cur" ]; then
                local pct=$(( cur * 100 / total ))
                [ "$pct" -gt 99 ] && pct=99   # 100 печатает уже сам вызов
                printf 'PROGRESS %d\n' "$pct"
            fi
            sleep 0.25
        done
    ) &
    PROGRESS_PID=$!
}

progress_kill() {
    [ -n "$PROGRESS_PID" ] && kill "$PROGRESS_PID" 2>/dev/null
    PROGRESS_PID=""
}

progress_stop() {
    progress_kill
    printf 'PROGRESS 100\n'
}

# Имя, свободное в каталоге назначения: не затираем существующее молча,
# а дописываем номер. Слова тут нарочно нет — скрипт не знает язык
# интерфейса.
uniq_target() {   # $1 — каталог назначения, $2 — имя
    local dst=$1 name=$2
    local target="$dst/$name"
    [ -e "$target" ] || { printf '%s' "$target"; return; }
    local base="${name%.*}" ext="${name##*.}" n=2
    while [ -e "$target" ]; do
        if [ "$base" = "$name" ]; then target="$dst/$name-$n"
        else                           target="$dst/$base-$n.$ext"; fi
        n=$((n + 1))
    done
    printf '%s' "$target"
}

case "$1" in
    # list <каталог> [hidden]
    # hidden — показывать файлы с точки. В домашнем каталоге почти всё
    # интересное начинается именно с неё (.config, .local), и прятать их
    # значит прятать ровно то, ради чего сюда и заходят.
    list)
        DIR="${2:-$HOME}"
        DIR="${DIR/#\~/$HOME}"
        py - "$DIR" "${3:-}" <<'EOF'
import os, sys, mimetypes

d = sys.argv[1]
show_hidden = len(sys.argv) > 2 and sys.argv[2] == 'hidden'
try:
    entries = list(os.scandir(d))
except OSError:
    sys.exit(0)

dirs, files = [], []
for e in entries:
    if e.name.startswith('.') and not show_hidden:
        continue
    try:
        st = e.stat()
    except OSError:
        continue
    if e.is_dir():
        dirs.append((e.name, 0, int(st.st_mtime), 'inode/directory'))
    else:
        mime = mimetypes.guess_type(e.name)[0] or 'application/octet-stream'
        files.append((e.name, st.st_size, int(st.st_mtime), mime))

key = lambda t: t[0].lower()
for name, size, mtime, mime in sorted(dirs, key=key):
    print(f"d|{name}|{size}|{mtime}|{mime}")
for name, size, mtime, mime in sorted(files, key=key):
    print(f"f|{name}|{size}|{mtime}|{mime}")
EOF
        ;;

    apps)
        P="${2:?}"
        P="${P/#\~/$HOME}"
        MIME=$(xdg-mime query filetype "$P" 2>/dev/null)
        DEFAULT=$(xdg-mime query default "$MIME" 2>/dev/null)
        py - "$MIME" "$DEFAULT" <<'EOF'
import configparser, os, sys

mime, default = sys.argv[1], sys.argv[2]
dirs = [os.path.expanduser("~/.local/share/applications"),
        "/usr/local/share/applications", "/usr/share/applications"]

group = mime.split("/")[0] + "/" if "/" in mime else ""

exact, similar, rest = {}, {}, {}
for d in dirs:
    if not os.path.isdir(d):
        continue
    for fn in os.listdir(d):
        if not fn.endswith(".desktop"):
            continue
        if fn in exact or fn in similar or fn in rest:
            continue
        cp = configparser.RawConfigParser(strict=False)
        try:
            cp.read(os.path.join(d, fn), encoding="utf-8")
            e = cp["Desktop Entry"]
        except Exception:
            continue
        if e.get("NoDisplay", "false").lower() == "true":
            continue
        if e.get("Type", "Application") != "Application":
            continue

        item = (e.get("Name", fn), e.get("Icon", ""))
        mimes = [m for m in e.get("MimeType", "").split(";") if m]
        if mime and mime in mimes:
            exact[fn] = item
        elif group and any(m.startswith(group) for m in mimes):
            similar[fn] = item
        else:
            # Мало какая программа объявляет все типы, которые тянет.
            # Показываем и остальные — пусть выбор будет за человеком.
            rest[fn] = item

def emit(fn, table):
    name, icon = table[fn]
    print(f"{fn}|{name}|{icon}")

# приложение по умолчанию — первой строкой, в какой бы группе ни оказалось
for table in (exact, similar, rest):
    if default in table:
        emit(default, table)
        break

for table in (exact, similar, rest):
    for fn in sorted(table, key=lambda f: table[f][0].lower()):
        if fn != default:
            emit(fn, table)
EOF
        ;;

    open)
        P="${2:?}"
        P="${P/#\~/$HOME}"
        DESKTOP="$3"
        if [ -n "$DESKTOP" ]; then
            for d in "$HOME/.local/share/applications" /usr/local/share/applications \
                     /usr/share/applications; do
                if [ -f "$d/$DESKTOP" ]; then
                    setsid gio launch "$d/$DESKTOP" "$P" >/dev/null 2>&1 &
                    exit 0
                fi
            done
        fi
        setsid xdg-open "$P" >/dev/null 2>&1 &
        ;;

    mkdir)
        D="${2:?}"; N="${3:?}"
        D="${D/#\~/$HOME}"
        mkdir -p "$D/$N"
        ;;

    rename)
        P="${2:?}"; N="${3:?}"
        P="${P/#\~/$HOME}"
        mv -n "$P" "$(dirname "$P")/$N"
        ;;

    trash)
        shift
        for P; do
            P="${P/#\~/$HOME}"
            gio trash "$P" 2>/dev/null || rm -rf -- "$P"
        done
        ;;

    extract)
        SRC="${2:?}"
        DST="${3:-}"
        SRC="${SRC/#\~/$HOME}"
        [ -f "$SRC" ] || exit 1

        if [ -z "$DST" ]; then
            DST="$(dirname "$SRC")"
        fi
        DST="${DST/#\~/$HOME}"
        mkdir -p "$DST" || exit 1

        if command -v bsdtar >/dev/null 2>&1; then
            bsdtar -xf "$SRC" -C "$DST"
        elif [[ "$SRC" =~ \.zip$ ]] && command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$SRC" -d "$DST"
        elif [[ "$SRC" =~ \.7z$ ]] && command -v 7z >/dev/null 2>&1; then
            7z x -y -o"$DST" "$SRC"
        elif [[ "$SRC" =~ \.rar$ ]] && command -v unrar >/dev/null 2>&1; then
            unrar x -y "$SRC" "$DST/"
        else
            tar -xf "$SRC" -C "$DST"
        fi
        ;;

    # Каталог назначения идёт первым, источники — списком: так один вызов
    # переносит хоть один файл, хоть выделение целиком, и полоска считает
    # общий объём, а не каждый файл заново.
    # Что из перетаскиваемого уже лежит в каталоге назначения. Печатает по
    # одному имени в строке; пусто — совпадений нет.
    #
    # Спрашиваем отдельно, а не разбираемся по ходу копирования: решение о
    # перезаписи принимает человек, и принять его надо ДО того, как первый файл
    # уже перезаписан. Заодно вопрос задаётся один раз на всю пачку, а не по
    # файлу.
    conflicts)
        DST="${2:?}"; shift 2
        DST="${DST/#\~/$HOME}"
        for src; do
            src="${src/#\~/$HOME}"
            name="$(basename "$src")"
            # Сам себя файл не перекрывает: источник и цель — одно и то же.
            [ "$src" = "$DST/$name" ] && continue
            [ -e "$DST/$name" ] && printf '%s\n' "$name"
        done
        ;;

    copy|move)
        op="$1"
        DST="${2:?}"
        # Что делать с уже существующими именами:
        #   keepboth  — рядом, с номером (как было всегда)
        #   overwrite — заменить
        #   skip      — не трогать, оставить как есть
        MODE="${3:-keepboth}"
        shift 3
        DST="${DST/#\~/$HOME}"
        [ "$#" -gt 0 ] || exit 0

        srcs=(); targets=()
        for src; do
            src="${src/#\~/$HOME}"
            [ -e "$src" ] || continue
            name="$(basename "$src")"
            case "$MODE" in
                overwrite) target="$DST/$name" ;;
                skip)
                    # Уже есть — просто пропускаем этот файл, остальные едут.
                    [ -e "$DST/$name" ] && [ "$src" != "$DST/$name" ] && continue
                    target="$DST/$name"
                    ;;
                *) target="$(uniq_target "$DST" "$name")" ;;
            esac
            srcs+=("$src")
            targets+=("$target")
        done
        [ "${#srcs[@]}" -gt 0 ] || exit 0

        # Оболочку могут убить вместе с панелью, и без этого счётчик остался бы
        # сиротой: крутиться вечно, раз в четверть секунды обходя каталог.
        trap progress_kill EXIT INT TERM

        total=$(du -sbc "${srcs[@]}" 2>/dev/null | tail -1 | cut -f1)
        progress_start "${total:-0}" "${targets[@]}"

        for i in "${!srcs[@]}"; do
            # При замене цель сносим заранее, а не полагаемся на -f.
            #
            # И cp, и mv, встретив на месте цели КАТАЛОГ, кладут источник
            # ВНУТРЬ него: вместо замены папки «Фото» получалась бы
            # «Фото/Фото». Для файлов -f сработал бы, для каталогов — нет,
            # поэтому убираем цель сами и в обоих случаях.
            if [ "$MODE" = "overwrite" ] && [ -e "${targets[$i]}" ] \
               && [ "${srcs[$i]}" != "${targets[$i]}" ]; then
                rm -rf -- "${targets[$i]}"
            fi

            if [ "$op" = "copy" ]; then
                cp -r --no-clobber "${srcs[$i]}" "${targets[$i]}"
            else
                mv -n "${srcs[$i]}" "${targets[$i]}"
            fi
        done

        progress_stop
        ;;

    copypath)
        P="${2:?}"
        P="${P/#\~/$HOME}"
        printf '%s' "$P" | wl-copy
        ;;

    places)
        # Подписи здесь черновые: интерфейс переводит их сам по ключу.
        printf 'home|%s|Home\n' "$HOME"
        for k in Downloads Documents Pictures Videos Music Desktop; do
            [ -d "$HOME/$k" ] && printf '%s|%s/%s|%s\n' "${k,,}" "$HOME" "$k" "$k"
        done
        printf 'root|/|System\n'
        # корзина — последней: это не место, куда ходят по делу
        printf 'trash|%s/Trash/files|Trash\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
        ;;

disks)
    # Смонтированные носители: свои разделы и съёмные отдельно.
    #   вид|путь|подпись|всего_байт|занято_байт|устройство
    # вид: disk (внутренний) | removable (флешка, карта, телефон)
    #
    # Список берём у df, а не у lsblk с eval: колонка PATH у lsblk
    # затирала бы переменную PATH самого скрипта, и дальше в нём не
    # находилось бы ни одной команды.
    df -B1 --output=source,target,size,used -x tmpfs -x devtmpfs -x squashfs \
           -x overlay -x efivarfs -x ramfs 2>/dev/null | tail -n +2 |
    while read -r src target size used rest; do
        case "$src" in /dev/*) ;; *) continue ;; esac
        case "$target" in /boot*|/efi*|/var/lib/docker*|/snap/*) continue ;; esac
        # btrfs-подтома повторяют одно устройство — оставляем первый
        case " $seen " in *" $src "*) continue ;; esac
        seen="$seen $src"

        label=$(lsblk -no LABEL "$src" 2>/dev/null | head -1)
        [ -n "$label" ] || label=$(basename "$target")
        [ "$target" = "/" ] && label="System"

        rm=$(lsblk -no RM "$src" 2>/dev/null | head -1 | tr -d ' ')
        hp=$(lsblk -no HOTPLUG "$src" 2>/dev/null | head -1 | tr -d ' ')
        if [ "$rm" = "1" ] || [ "$hp" = "1" ]; then kind=removable; else kind=disk; fi

        printf '%s|%s|%s|%s|%s|%s\n' "$kind" "$target" "$label" "$size" "$used" "$src"
    done

    # Телефоны и всё, что примонтировано через mtp напрямую: блочного
    # устройства у них нет, размер тоже обычно не отдаётся.
    awk '$3 ~ /^(fuse\.(mtpfs|jmtpfs|simple-mtpfs)|mtpfs)$/ {print $2}' \
        /proc/mounts 2>/dev/null |
    while read -r mp; do
        mp=$(printf '%b' "$mp")
        [ -d "$mp" ] || continue
        printf 'removable|%s|%s|0|0|mtp\n' "$mp" "$(basename "$mp")"
    done

    # gvfs разбираем отдельно, и вот почему. Его точка монтирования —
    # /run/user/1000/gvfs — не устройство, а корень виртуальной файловой
    # системы: он существует всё время, пока запущен демон gvfs, и пуст, пока
    # ничего не подключено. Раньше он попадал в список наравне с mtp, и в
    # «Съёмных» вечно висела запись «gvfs», за которой ничего не стоит.
    #
    # Настоящие устройства лежат ВНУТРИ него отдельными каталогами вида
    # mtp:host=Samsung_Galaxy_1234. Их и показываем — по одному на устройство,
    # с именем, приведённым к читаемому виду.
    awk '$3 == "fuse.gvfsd-fuse" {print $2}' /proc/mounts 2>/dev/null |
    while read -r root; do
        root=$(printf '%b' "$root")
        [ -d "$root" ] || continue
        for dev in "$root"/*; do
            [ -d "$dev" ] || continue
            name=$(basename "$dev")
            pretty=$(printf '%s' "$name" \
                | sed 's/^[a-zA-Z0-9+.-]*:host=//; s/%2C.*$//; s/%20/ /g; s/_/ /g')
            [ -n "$pretty" ] || pretty="$name"
            printf 'removable|%s|%s|0|0|gvfs\n' "$dev" "$pretty"
        done
    done
    ;;

    emptytrash)
        # gio trash --empty ходит через gvfs, а его в системе может не быть
        # («Operation not supported»). Чистим корзину сами — она устроена
        # ровно по freedesktop-спецификации: files, info и expunged.
        base="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
        case "$base" in
            */Trash) ;;
            *) exit 1 ;;          # подстраховка: мало ли что в переменной
        esac
        for d in files info expunged; do
            [ -d "$base/$d" ] || continue
            find "$base/$d" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        done
        ;;

    trashcount)
        d="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files"
        [ -d "$d" ] || { echo 0; exit 0; }
        find "$d" -mindepth 1 -maxdepth 1 | wc -l
        ;;

    *)
        echo "usage: files.sh list DIR | disks | apps P | open P [D] | mkdir D N | rename P N | trash P | copy S D | move S D | copypath P | places | emptytrash | trashcount" >&2
        exit 1
        ;;
esac
