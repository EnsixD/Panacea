#!/usr/bin/env bash
# Panacea dotfiles installer.
#
# Installs everything: the Quickshell pill, the Hyprland Lua config, the
# terminals, the shell, fastfetch — the whole rice. Nothing is optional here;
# for a pick-and-choose install the pieces are gated inside the shell itself.
#
#   ./install.sh              install everything
#   ./install.sh --no-deps    skip the package step (configs only)
#   ./install.sh --no-sddm    don't touch the SDDM login theme
#   ./install.sh --no-grub    don't touch the GRUB boot theme
#   ./install.sh --yes        answer yes to every prompt
#   ./install.sh --print-missing   only name the packages that are absent
#   ./install.sh --print-obsolete  only name the ones no longer used
#
# Whatever already sits at a destination is moved to <name>.bak-<timestamp>
# beside it — nothing is deleted.

set -uo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

DO_DEPS=1
# Только назвать, чего не хватает, и выйти — ничего не ставя и не копируя.
# Этим пользуется update.sh: список зависимостей должен жить в одном месте,
# а не расходиться двумя копиями.
PRINT_MISSING=0
PRINT_OBSOLETE=0
DO_SDDM=1
DO_GRUB=1
# Обновлению и проверкам это не нужно: службы уже включены, обои уже скачаны,
# а перезапуск оболочки в песочнице убил бы рабочую.
DO_SERVICES=1
DO_WALLS=1
DO_RESTART=1
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --no-deps) DO_DEPS=0 ;;
        --no-sddm) DO_SDDM=0 ;;
        --no-grub) DO_GRUB=0 ;;
        --no-services) DO_SERVICES=0 ;;
        --no-wallpapers) DO_WALLS=0 ;;
        --no-restart) DO_RESTART=0 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        --print-missing) PRINT_MISSING=1 ;;
        --print-obsolete) PRINT_OBSOLETE=1 ;;
        --help|-h) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------- presentation
if [ -t 1 ]; then
    B=$'\e[1m'; DIM=$'\e[2m'; OK=$'\e[32m'; WARN=$'\e[33m'; ERR=$'\e[31m'; N=$'\e[0m'
else
    B=""; DIM=""; OK=""; WARN=""; ERR=""; N=""
fi
step() { printf '\n%s▍ %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$OK" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$WARN" "$N" "$*"; }
die()  { printf '\n%sError:%s %s\n' "$ERR" "$N" "$*" >&2; exit 1; }

ask() {  # ask "question" -> 0 for yes
    [ "$ASSUME_YES" = "1" ] && return 0
    printf '%s%s [y/N]%s ' "$B" "$1" "$N"
    read -r a; case "${a,,}" in y|yes) return 0 ;; *) return 1 ;; esac
}

# ------------------------------------------------------------------ dependencies
# binary|package|what it is for
DEPS=(
    "Hyprland|hyprland|the compositor"
    "qs|quickshell|the pill (AUR)"
    "fish|fish|the shell"
    "foot|foot|terminal"
    "hyprpaper|hyprpaper|wallpaper"
    "hyprsunset|hyprsunset|night colour temperature"
    # Не ради самой программы — она даже не запускается, и её конфига здесь
    # нет. Пакет кладёт /etc/pam.d/swaylock, а это профиль, которым проверяют
    # пароль экран блокировки и хранилище паролей: без него ни то, ни другое
    # не открывается.
    "swaylock|swaylock|the PAM profile the lock screen and the vault use"
    "jq|jq|JSON in the scripts"
    "wl-copy|wl-clipboard|clipboard access"
    "cliphist|cliphist|clipboard history"
    "grim|grim|screenshots"
    "slurp|slurp|region select"
    "ffmpeg|ffmpeg|media player, trimming, thumbnails"
    "wf-recorder|wf-recorder|screen recording"
    "brightnessctl|brightnessctl|brightness keys"
    "playerctl|playerctl|media keys"
    "wpctl|wireplumber|audio control"
    "eza|eza|ls replacement"
    "zoxide|zoxide|smarter cd"
    # Super + Shift + E из списка сочетаний: без него биндинг открывал бы
    # пустой терминал. Браузер и заметки сюда не входят нарочно — это выбор
    # человека, а не часть оболочки
    "yazi|yazi|files in the terminal"
    "python3|python|helper scripts"
    "rfkill|util-linux|Bluetooth soft-unblock"
    "openssl|openssl|encrypting the password vault"
    "xdg-open|xdg-utils|opening files and links from the pill"
    "gio|glib2|trash and launching desktop entries"
    "upower|upower|battery state and the battery page"
    "lsblk|util-linux|disks and removable media in the file manager"
    "cava|cava|the audio spectrum in the pill"
    "mpvpaper|mpvpaper|live video wallpapers (AUR)"
    "curl|curl|downloading the wallpaper pack"
    "file|file|sanity-checking downloaded wallpapers"
    # обновление оболочки из репозитория и сведения о железе на вкладке System
    "git|git|updating the shell from the repository"
    "lspci|pciutils|naming the graphics card on the System page"
    "timedatectl|systemd|time zone and clock on the Clock & Date page"
)
FILE_DEPS=(
    "/usr/lib/qt6/qml/QtMultimedia/qmldir|qt6-multimedia|video playback"
    "/usr/lib/qt6/qml/QtQuick/Controls/qmldir|qt6-declarative|UI controls"
    # MultiEffect — скруглённые маски превью обоев и макетов настроек,
    # Shapes — вогнутые уголки примыкания острова на макетах
    "/usr/lib/qt6/qml/QtQuick/Effects/qmldir|qt6-declarative|rounded image masks"
    "/usr/lib/qt6/qml/QtQuick/Shapes/qmldir|qt6-declarative|island notch corners"
)
EXTRA_PKGS=(power-profiles-daemon bluez bluez-utils iwd cava pipewire-audio
            ttf-jetbrains-mono-nerd papirus-icon-theme
            # носители в проводнике: udisks2 монтирует, udiskie делает это
            # автоматически при подключении — без него раздел «Съёмные»
            # появится только после ручного монтирования
            udisks2 udiskie
            # телефоны по MTP: без gvfs они не монтируются и раздел
            # «Съёмные» их не увидит
            gvfs gvfs-mtp
            # необязательные: без них импорт паролей из браузеров просто
            # пропускает соответствующее семейство, всё остальное работает
            python-secretstorage python-cryptography)
FONT_PKG="ttf-jetbrains-mono-nerd"

# Пакеты, которые Panacea ставила раньше и больше не использует. Установщик
# их не трогает: человек мог поставить waybar или tofi для себя, и удалять
# чужое за него — не дело обновления. Оно только называет их, а решает он.
#
# Формат: пакет|версия, в которой он перестал быть нужен. Версия — не
# украшение: список имеет смысл, только пока есть копии старше неё, а потом
# сам превращается в тот же мусор, ради уборки которого заведён. Чтобы это
# не держалось на чьей-то памяти, panacea/scripts/check.sh сверяет её с
# текущей версией оболочки и напоминает выкинуть просроченное.
OBSOLETE_PKGS=(
    # режим энергосбережения больше не подменяет оболочку вторым набором
    # панелей — пилюля остаётся и просто гасит эффекты
    "waybar|1.0.7"
    "wob|1.0.7"
    "tofi|1.0.7"
    # экран блокировки давно свой, на quickshell (lock.qml)
    "hyprlock|1.0.7"
)

MISSING=()
check_deps() {
    for row in "${DEPS[@]}"; do
        IFS='|' read -r bin pkg why <<<"$row"
        if command -v "$bin" >/dev/null 2>&1; then ok "$bin"
        else warn "missing $bin — $why"; MISSING+=("$pkg"); fi
    done
    for row in "${FILE_DEPS[@]}"; do
        IFS='|' read -r path pkg why <<<"$row"
        if [ -e "$path" ]; then ok "$pkg"
        else warn "missing $pkg — $why"; MISSING+=("$pkg"); fi
    done
    # grep -q закрыл бы пайп на первом совпадении, fc-list получил бы SIGPIPE,
    # и pipefail засчитал бы всей проверке провал: шрифт «отсутствовал» даже
    # когда стоял на месте. Дочитываем вывод до конца.
    if fc-list 2>/dev/null | grep -i "JetBrainsMono.*Nerd" >/dev/null; then ok "JetBrainsMono Nerd Font"
    else warn "missing the Nerd Font — every icon is a glyph"; MISSING+=("$FONT_PKG"); fi
    # these have no simple binary to probe — let pacman skip what's present
    MISSING+=("${EXTRA_PKGS[@]}")
}

aur_helper() {
    for h in yay paru pikaur; do command -v "$h" >/dev/null 2>&1 && { echo "$h"; return; }; done
}

install_deps() {
    command -v pacman >/dev/null 2>&1 || {
        warn "not an Arch system — install these yourself, then rerun with --no-deps:"
        printf '    %s\n' "${MISSING[@]}"; return 1
    }
    # unique
    local uniq; mapfile -t uniq < <(printf '%s\n' "${MISSING[@]}" | sort -u)
    local repo=() aur=()
    for p in "${uniq[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
    done
    if [ ${#repo[@]} -gt 0 ]; then
        printf '  installing from the repos: %s\n' "${repo[*]}"
        sudo pacman -S --needed "${repo[@]}" || return 1
    fi
    if [ ${#aur[@]} -gt 0 ]; then
        local h; h=$(aur_helper)
        [ -z "$h" ] && { warn "these are in the AUR — install yay or paru first: ${aur[*]}"; return 1; }
        printf '  installing from the AUR via %s: %s\n' "$h" "${aur[*]}"
        "$h" -S --needed "${aur[@]}" || return 1
    fi
    ok "dependencies in place"
}

# --------------------------------------------------------------------- copying
backup() {
    [ -e "$1" ] || return 0
    mv "$1" "$1.bak-$STAMP"
    warn "existing $(basename "$1") saved as $(basename "$1").bak-$STAMP"
}

copy_into_config() {   # copy_into_config <dir-in-repo>
    local name="$1" dst="$CONF/$1"
    [ -d "$SRC/$name" ] || { warn "no $name in this checkout — skipping"; return; }
    backup "$dst"
    cp -r "$SRC/$name" "$dst"
    ok "$name → $dst"
}

install_configs() {
    mkdir -p "$CONF" "$HOME/.local/bin"
    for d in panacea hypr foot ghostty kitty fish fastfetch nano; do
        [ -d "$SRC/$d" ] && copy_into_config "$d"
    done
    # nanorc lives at ~/.nanorc, not in a directory
    if [ -f "$SRC/nano/nanorc" ]; then
        backup "$HOME/.nanorc"; cp "$SRC/nano/nanorc" "$HOME/.nanorc"; ok "nanorc → ~/.nanorc"
    fi
    if [ -d "$SRC/bin" ]; then
        cp "$SRC"/bin/* "$HOME/.local/bin/" 2>/dev/null
        chmod +x "$HOME"/.local/bin/* 2>/dev/null
        ok "helper scripts → ~/.local/bin"
    fi
    chmod +x "$CONF"/panacea/scripts/*.sh 2>/dev/null
    chmod +x "$CONF"/panacea/scripts/*.py 2>/dev/null
    chmod +x "$CONF"/hypr/scripts/*.sh 2>/dev/null
    # каталог живых обоев: карусель открывает его кнопкой, и он должен
    # существовать ещё до того, как туда что-то положат
    mkdir -p "$CONF/hypr/wallpaper/live"
    stamp_version
    personalize_paths
}

# Какую версию поставили. По этой отметке оболочка потом понимает, что на
# GitHub появилось что-то новее, и предлагает обновиться. Ставили из клона —
# берём хеш прямо из него; из архива — спрашиваем конец ветки у GitHub.
stamp_version() {
    local sha=""
    if [ -d "$SRC/.git" ] && command -v git >/dev/null 2>&1; then
        sha="$(git -C "$SRC" rev-parse HEAD 2>/dev/null)"
    fi
    if [ -z "$sha" ] && command -v git >/dev/null 2>&1; then
        sha="$(git ls-remote https://github.com/EnsixD/Panacea.git main 2>/dev/null | cut -f1)"
    fi
    if [ -n "$sha" ]; then
        printf '%s\n' "$sha" > "$CONF/panacea/.version"
        ok "version stamp ${sha:0:7}"
    else
        warn "could not determine version — the shell will not offer updates"
    fi
}

# В репозитории часть путей записана как /home/ensi — так их писал автор.
# На чужой машине это молча ломало обои, темы (тема переставала
# восстанавливаться после перезагрузки) и мультимедийные клавиши.
# После копирования переписываем их на домашний каталог того, кто ставит.
personalize_paths() {
    [ "$HOME" = "/home/ensi" ] && return 0
    local n=0
    while IFS= read -r f; do
        sed -i "s|/home/ensi|$HOME|g" "$f" && n=$((n + 1))
    done < <(grep -rl '/home/ensi' "$CONF/hypr" "$CONF/panacea" "$HOME/.local/bin" 2>/dev/null)
    [ "$n" -gt 0 ] && ok "paths rewritten to $HOME in $n files"
    return 0
}

# ------------------------------------------------------------------- services
enable_services() {
    command -v systemctl >/dev/null 2>&1 || return 0
    # Bluetooth and power profiles are what the pill talks to; iwd backs Wi-Fi,
    # upower feeds the charge indicator in the pill and the battery page.
    for svc in bluetooth power-profiles-daemon iwd upower; do
        if systemctl list-unit-files "$svc.service" >/dev/null 2>&1; then
            sudo systemctl enable --now "$svc.service" >/dev/null 2>&1 \
                && ok "$svc enabled" || warn "could not enable $svc"
        fi
    done
    # soft-unblock radios so Bluetooth/Wi-Fi come up without a manual rfkill
    command -v rfkill >/dev/null 2>&1 && rfkill unblock all 2>/dev/null
}

# ------------------------------------------------------------- SDDM login theme
install_sddm() {
    [ -d "$SRC/sddm/panacea" ] || { warn "no SDDM theme here — skipping"; return; }
    command -v sddm >/dev/null 2>&1 || { warn "SDDM not installed — skipping login theme"; return; }
    local themes=/usr/share/sddm/themes
    sudo rm -rf "$themes/panacea" && sudo cp -r "$SRC/sddm/panacea" "$themes/" || { warn "SDDM theme copy failed"; return; }
    sudo mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=panacea\n' | sudo tee /etc/sddm.conf.d/10-panacea.conf >/dev/null

    # Мостик к экрану входа: greeter работает от пользователя sddm и в
    # закрытый ~/ заглянуть не может. Каталог отдаём во владение
    # пользователю — switch_theme.sh кладёт туда размытые обои, palette.sh
    # акцент палитры, пилюля дописывает выбранный язык, а sddm только читает.
    sudo mkdir -p /var/lib/panacea
    sudo chown "$(id -un):$(id -gn)" /var/lib/panacea
    sudo chmod 755 /var/lib/panacea

    ok "SDDM login theme installed and selected"
}



# ------------------------------------------------------------------------ grub
# Тема загрузчика живёт не в ~/.config, а в /boot — поэтому отдельным шагом и
# под sudo. Раньше каталог grub/ вообще не устанавливался: на диске оставалась
# та версия темы, что попала туда руками, и правки в репозитории ни на что не
# влияли.
install_grub() {
    local src="$SRC/grub/panacea"
    [ -d "$src" ] || { warn "no grub theme in this checkout — skipping"; return; }
    command -v grub-mkconfig >/dev/null 2>&1 || command -v grub2-mkconfig >/dev/null 2>&1 || {
        warn "grub-mkconfig not found — skipping the boot theme"; return; }

    local dst=/boot/grub/themes/panacea
    sudo mkdir -p /boot/grub/themes || { warn "cannot write to /boot/grub — skipping"; return; }
    sudo rm -rf "$dst" && sudo cp -r "$src" "$dst" \
        || { warn "boot theme copy failed"; return; }

    # Прописываем тему и режим меню в /etc/default/grub, если их там ещё нет.
    # Существующие строки правим на месте, чтобы не плодить дубликаты.
    local def=/etc/default/grub
    if [ -f "$def" ]; then
        sudo cp "$def" "$def.bak-$STAMP"
        set_grub_key "$def" GRUB_THEME "\"$dst/theme.txt\""
        set_grub_key "$def" GRUB_TIMEOUT_STYLE "menu"
        # 1920x1080 с запасным auto: без явного режима GRUB иногда встаёт в
        # 640x480, и тема с её процентами выглядит растянутой
        set_grub_key "$def" GRUB_GFXMODE "1920x1080,auto"
        set_grub_key "$def" GRUB_GFXPAYLOAD_LINUX "keep"
    fi

    local out=/boot/grub/grub.cfg
    if command -v grub-mkconfig >/dev/null 2>&1; then
        sudo grub-mkconfig -o "$out" >/dev/null 2>&1 && ok "boot theme installed → $dst"
    else
        sudo grub2-mkconfig -o "$out" >/dev/null 2>&1 && ok "boot theme installed → $dst"
    fi
}

# set_grub_key <файл> <ключ> <значение>
set_grub_key() {
    local f="$1" k="$2" v="$3"
    if sudo grep -qE "^[[:space:]]*$k=" "$f"; then
        sudo sed -i "s|^[[:space:]]*$k=.*|$k=$v|" "$f"
    else
        printf '%s=%s\n' "$k" "$v" | sudo tee -a "$f" >/dev/null
    fi
}

# ------------------------------------------------------------------ wallpapers
# Репозиторий несёт только пару обоев: набор целиком — это 400 МБ, в dotfiles
# такому места нет. Поэтому предлагаем скачать его отдельно, файлами, без
# истории (git clone тянул бы полгигабайта).
WALLS_REPO="ilyamiro/shell-wallpapers"
install_wallpapers() {
    local dst="$CONF/hypr/wallpaper/shell"
    command -v curl >/dev/null 2>&1 || { warn "curl not found — skipping the wallpaper pack"; return; }
    command -v python3 >/dev/null 2>&1 || { warn "python3 not found — skipping the wallpaper pack"; return; }

    mkdir -p "$dst" || return
    local list; list=$(mktemp)
    curl -fsSL "https://api.github.com/repos/$WALLS_REPO/git/trees/master?recursive=1" \
        | python3 -c "
import json, sys, urllib.parse
try:
    tree = json.load(sys.stdin).get('tree', [])
except Exception:
    sys.exit(1)
for e in tree:
    p = e.get('path', '')
    if e.get('type') == 'blob' and p.startswith('images/') \
       and p.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
        print('https://raw.githubusercontent.com/$WALLS_REPO/master/' + urllib.parse.quote(p))
" > "$list" || { warn "could not read the wallpaper list"; rm -f "$list"; return; }

    local n; n=$(wc -l < "$list")
    [ "$n" -gt 0 ] || { warn "the wallpaper list came back empty"; rm -f "$list"; return; }
    printf '  downloading %s wallpapers (about 400 MB)\n' "$n"

    # Прогресс считаем со стороны: curl'ов восемь штук разом, и их собственные
    # полоски перебивали бы друг друга. Раз в секунду смотрим, сколько файлов
    # уже лежит в каталоге и сколько это мегабайт, и переписываем одну строку.
    #
    # Без этого 400 МБ выглядели как зависший установщик: он молчал минутами,
    # и понять, идёт закачка или встала, было нельзя.
    # Строку переписываем через \r, поэтому в файл её лить нельзя: в логе
    # установки получилась бы каша из сотни строк. Не терминал — молчим.
    local mon=""
    if [ -t 1 ]; then
        local done_before; done_before=$(find "$dst" -type f 2>/dev/null | wc -l)
        (
            while :; do
                have=$(find "$dst" -type f 2>/dev/null | wc -l)
                mb=$(du -sm "$dst" 2>/dev/null | cut -f1)
                printf '\r  %s/%s files · %s MB   ' \
                       "$((have - done_before))" "$n" "${mb:-0}"
                sleep 1
            done
        ) &
        mon=$!
        # Счётчик не должен пережить установщик, если тот прервали
        trap 'kill "$mon" 2>/dev/null' EXIT INT TERM
    fi

    (cd "$dst" && xargs -P 8 -n 1 curl -sfLO --retry 2 --max-time 180 < "$list")

    if [ -n "$mon" ]; then
        kill "$mon" 2>/dev/null
        trap - EXIT INT TERM
        printf '\r%*s\r' 44 ''   # стираем строку прогресса за собой
    fi
    rm -f "$list"

    # Битые и не-картинки выбрасываем: одна такая ломала бы карусель
    local bad=0
    for f in "$dst"/*; do
        [ -f "$f" ] || continue
        case "$(file -b --mime-type "$f")" in
            image/*) ;;
            *) rm -f "$f"; bad=$((bad + 1)) ;;
        esac
    done
    # Имена с процентами и пробелами ломают file://-пути в Qt
    local before after
    for f in "$dst"/*; do
        [ -f "$f" ] || continue
        before=$(basename "$f")
        after=$(printf '%s' "$before" | tr ' ' '_' | tr -cd '[:alnum:]._-')
        [ -n "$after" ] && [ "$after" != "$before" ] && [ ! -e "$dst/$after" ] \
            && mv -f "$f" "$dst/$after"
    done
    ok "wallpapers → $dst$( [ "$bad" -gt 0 ] && printf ' (%s broken files dropped)' "$bad" )"
}

# ------------------------------------------------------------------------ run

# Список для машины: по одному имени пакета в строке, без украшений и без
# единого вопроса — этим пользуется update.sh, чтобы сказать, чего не хватает
# после обновления. Список зависимостей должен жить в одном месте, а не
# расходиться двумя копиями, поэтому отчёт берётся отсюда же.
#
# EXTRA_PKGS сюда не идут: у них нет бинарника, который можно проверить, и в
# MISSING они попадают всегда — для отчёта это был бы шум.
# То же для пакетов, которые больше не нужны: называем только те, что
# действительно стоят в системе.
if [ "$PRINT_OBSOLETE" = "1" ]; then
    command -v pacman >/dev/null 2>&1 || exit 0
    for row in "${OBSOLETE_PKGS[@]}"; do
        IFS='|' read -r pkg since <<<"$row"
        pacman -Qq "$pkg" >/dev/null 2>&1 && printf '%s\n' "$pkg"
    done
    exit 0
fi

if [ "$PRINT_MISSING" = "1" ]; then
    for row in "${DEPS[@]}"; do
        IFS='|' read -r bin pkg why <<<"$row"
        command -v "$bin" >/dev/null 2>&1 || printf '%s\n' "$pkg"
    done
    for row in "${FILE_DEPS[@]}"; do
        IFS='|' read -r path pkg why <<<"$row"
        [ -e "$path" ] || printf '%s\n' "$pkg"
    done
    fc-list 2>/dev/null | grep -i "JetBrainsMono.*Nerd" >/dev/null || printf '%s\n' "$FONT_PKG"
    exit 0
fi

printf '\n%sPanacea%s — dotfiles installer\n' "$B" "$N"
printf '%sfrom %s%s\n' "$DIM" "$SRC" "$N"
[ -d "$SRC/panacea" ] || die "run this from inside the cloned repo"

printf '\n%sThis overwrites ~/.config/hypr, the terminal configs and more.\nEverything replaced is backed up as *.bak-%s next to it.%s\n' "$WARN" "$STAMP" "$N"
ask "Continue?" || { echo "Nothing done."; exit 0; }

step "Checking dependencies"
check_deps
if [ "$DO_DEPS" = "1" ]; then
    step "Installing packages"
    install_deps || warn "some packages are missing — the shell may be degraded until they are installed"
fi

step "Copying configs"
install_configs

if [ "$DO_SERVICES" = "1" ]; then
    step "Enabling services"
    enable_services
fi

if [ "$DO_WALLS" = "1" ] && ask "Download the wallpaper pack (~400 MB, $WALLS_REPO)?"; then
    step "Downloading wallpapers"
    install_wallpapers
fi

if [ "$DO_GRUB" = "1" ] && [ -d /boot/grub ]; then
    if ask "Install the Panacea GRUB theme? (writes to /boot, needs root)"; then
        step "Installing the boot theme"; install_grub
    fi
fi

if [ "$DO_SDDM" = "1" ] && command -v sddm >/dev/null 2>&1; then
    if ask "Also install the Panacea SDDM login theme? (replaces your current login screen, needs root)"; then
        step "Installing the login theme"; install_sddm
    fi
fi

# Палитра одна и лежит в hypr/palette.conf: palette.sh разносит её по
# терминалам, waybar, btop, редакторам и экрану входа. Компоновщик ей не нужен,
# поэтому шаг стоит отдельно: при установке из TTY цвета всё равно встанут, а
# раньше они ждали первого запуска руками.
step "Applying the palette"
if [ -x "$CONF/hypr/scripts/palette.sh" ]; then
    "$CONF/hypr/scripts/palette.sh" >/dev/null 2>&1 && ok "colours → terminals, waybar, btop, editors"
else
    warn "palette.sh missing — colours stay at their defaults"
fi
# Миниатюры обоев — в фоне: карусель показывает их мгновенно, а без прогрева
# первое открытие читало бы исходники по 4K.
[ -x "$CONF/panacea/scripts/thumbs.sh" ] \
    && (setsid "$CONF/panacea/scripts/thumbs.sh" all >/dev/null 2>&1 &) \
    && ok "wallpaper thumbnails warming up in the background"

# Идёт обновление? Тогда перезапуск не наш.
#
# Установщик убивает qs — а update.sh запущен ИЗ оболочки и умирал вместе с
# ней прямо здесь, не успев вернуть настройки, записать список изменений и
# отметить версию. Свежий update.sh теперь сам передаёт нам --no-restart, но
# у людей на руках старые копии, которые про это не знают. Решаем за них:
# идёт обновление — оболочку не трогаем, Quickshell сам перечитает файлы.
if pgrep -f "update\.sh apply" >/dev/null 2>&1; then
    DO_RESTART=0
fi

step "Starting the shell"
if [ "$DO_RESTART" != "1" ]; then
    ok "restart skipped"
elif command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1
    # Обои живут отдельно от палитры: ставим последние выбранные (на чистой
    # установке — те, что лежат в wallpaper.conf репозитория).
    [ -x "$CONF/hypr/scripts/switch_theme.sh" ] \
        && "$CONF/hypr/scripts/switch_theme.sh" --restore >/dev/null 2>&1
    pkill -x qs >/dev/null 2>&1; sleep 1
    (setsid qs -c "$CONF/panacea" >/dev/null 2>&1 &)
    ok "reloaded Hyprland and started the pill"
else
    warn "Hyprland isn't running here — everything comes up at next login"
fi

printf '\n%s✓ Done.%s Log out and back in for a clean start.\n' "$OK" "$N"
printf '%sSUPER+A launcher · SUPER+Z quick settings · SUPER+Tab workspaces · SUPER+E files%s\n' "$DIM" "$N"
printf '%sSUPER+I settings · SUPER+/ shortcuts · or hover the pill.%s\n' "$DIM" "$N"
