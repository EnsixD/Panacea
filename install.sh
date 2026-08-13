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
    # На настольной машине внутренней матрицы нет, и яркость монитора идёт по
    # DDC/CI поверх I2C — без ddcutil ползунок яркости показать не из чего.
    "ddcutil|ddcutil|monitor brightness on a desktop"
    "playerctl|playerctl|media keys"
    "wpctl|wireplumber|audio control"
    # Всё, на что опирается config.fish. Без них оболочка запустится, но
    # человек получит голый fish вместо описанного в конфиге: алиасы там
    # стоят под `type -q`, и молча пропускаются вместе с недостающей
    # программой — со стороны это выглядит как «алиасы не поставились».
    "eza|eza|ls replacement"
    "zoxide|zoxide|smarter cd"
    "bat|bat|cat with syntax highlighting"
    "fastfetch|fastfetch|system summary, its config ships with the shell"
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
            python-secretstorage python-cryptography
            # дуалбут: GRUB найдёт Windows и другие системы только с ним
            os-prober)
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

# ------------------------------------------------------------------- drivers
# Железо у всех разное, и ставить всё подряд нельзя: пакеты Nvidia на машине
# с одной интеловской графикой — это лишние гигабайты и лишний DKMS-модуль.
# Поэтому смотрим, что в машине на самом деле, и предлагаем ровно это.
#
# Микрокод обязателен: без него процессор живёт с ошибками, которые давно
# исправлены, и это то, о чём вспоминают в последнюю очередь.
detect_drivers() {
    DRIVERS=()
    DRIVER_NOTES=()

    local cpu; cpu=$(grep -m1 '^vendor_id' /proc/cpuinfo | cut -d: -f2 | tr -d ' ')
    case "$cpu" in
        AuthenticAMD) DRIVERS+=(amd-ucode);   DRIVER_NOTES+=("amd-ucode — AMD CPU microcode") ;;
        GenuineIntel) DRIVERS+=(intel-ucode); DRIVER_NOTES+=("intel-ucode — Intel CPU microcode") ;;
    esac

    # Вендора определяем по идентификатору PCI, а не по названию: строка
    # «VGA compatible controller» содержит «ati», и поиск по имени выдавал
    # AMD на любой машине, включая чисто nvidia'шную.
    #   1002 — AMD, 10de — Nvidia, 8086 — Intel
    local gpus; gpus=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d controller|display controller')

    if printf '%s' "$gpus" | grep -q '\[1002:'; then
        DRIVERS+=(mesa vulkan-radeon libva-mesa-driver)
        DRIVER_NOTES+=("mesa, vulkan-radeon, libva-mesa-driver — AMD graphics")
    fi
    if printf '%s' "$gpus" | grep -q '\[8086:'; then
        DRIVERS+=(mesa vulkan-intel intel-media-driver)
        DRIVER_NOTES+=("mesa, vulkan-intel, intel-media-driver — Intel graphics")
    fi
    if printf '%s' "$gpus" | grep -q '\[10de:'; then
        # Открытые модули или закрытые — не вопрос вкуса. Начиная с Turing
        # (RTX 20xx, GTX 16xx) Nvidia ведёт именно открытые, а для Blackwell
        # (RTX 50xx) закрытых не существует вовсе: на них система остаётся
        # с nouveau, который эти карты не тянет и роняет машину в перезагрузку.
        # Старым картам, наоборот, открытые модули не подходят.
        #
        # dkms, а не готовый модуль: собирается под любое ядро, включая -lts
        # и -zen, и переживает обновление ядра без чёрного экрана на следующем
        # старте. egl-wayland обязателен — без него Hyprland на Nvidia не
        # запускается совсем.
        # Заголовки установленного ядра: без них dkms собрать модуль не может,
        # и вместо драйвера получается «Failed to find module nvidia_uvm» в
        # журнале, nouveau на карте и монитор без EDID. Ядер может быть
        # несколько (linux, -lts, -zen) — заголовки нужны каждому.
        local k
        for k in linux linux-lts linux-zen linux-hardened; do
            pacman -Qq "$k" >/dev/null 2>&1 && DRIVERS+=("$k-headers")
        done
        DRIVER_NOTES+=("kernel headers — needed to build the driver module")

        if printf '%s' "$gpus" | grep -qiE 'rtx|gtx 16'; then
            DRIVERS+=(nvidia-open-dkms nvidia-utils egl-wayland)
            DRIVER_NOTES+=("nvidia-open-dkms, nvidia-utils, egl-wayland — Nvidia graphics (Turing and newer)")
        else
            DRIVERS+=(nvidia-dkms nvidia-utils egl-wayland)
            DRIVER_NOTES+=("nvidia-dkms, nvidia-utils, egl-wayland — Nvidia graphics (pre-Turing)")
        fi
    fi
}

install_drivers() {
    detect_drivers
    if [ "${#DRIVERS[@]}" -eq 0 ]; then
        warn "could not tell what hardware this is — skipping drivers"
        return
    fi
    printf '  found:\n'
    printf '    %s\n' "${DRIVER_NOTES[@]}"
    ask "Install these?" || { ok "drivers skipped"; return; }

    local uniq; mapfile -t uniq < <(printf '%s\n' "${DRIVERS[@]}" | sort -u)
    sudo pacman -S --needed "${uniq[@]}" || { warn "driver install failed"; return; }
    ok "drivers in place"

    # Nvidia на Wayland без этого либо не стартует, либо идёт рывками. Пишем
    # в отдельный файл, а не в конфиг Hyprland: он принадлежит машине, а не
    # дотфайлам, и переустановка их не затрёт.
    if printf '%s' "${uniq[*]}" | grep -q nvidia; then
        printf 'options nvidia_drm modeset=1\n' | sudo tee /etc/modprobe.d/nvidia-panacea.conf >/dev/null

        # Собрать модуль и переложить его в initramfs. pacman этого не делает
        # сам: свежепоставленный dkms-пакет собирается хуком, но если хук не
        # отработал (или заголовки приехали позже), модуля не будет, и карта
        # останется на nouveau без единой ошибки при установке.
        sudo dkms autoinstall >/dev/null 2>&1
        sudo mkinitcpio -P >/dev/null 2>&1
        if lsmod | grep -q '^nvidia' || modinfo nvidia >/dev/null 2>&1; then
            ok "Nvidia module built — reboot to load it"
        else
            warn "Nvidia module still missing — check 'dkms status' after reboot"
        fi
    fi
}

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

# ------------------------------------------------------------- своё состояние
# Что принадлежит человеку, а не репозиторию. Установщик уносит каталоги
# целиком и кладёт свежие — вместе со старым каталогом уезжали настройки из
# окна Super+I, сочетания клавиш и обои, и после каждой переустановки человек
# получал заводскую оболочку. Уносим своё в сторону до копирования и
# возвращаем после. Список тот же, что в scripts/update.sh.
KEEP_FILES=(
    "panacea/settings.json"
    "hypr/lua/binds_data.lua"
)
KEEP_DIRS=(
    "hypr/wallpaper"
    "panacea/assets"
)
KEEP_STASH=""

keep_stash() {
    KEEP_STASH="$(mktemp -d)" || { KEEP_STASH=""; return 0; }
    local f
    for f in "${KEEP_FILES[@]}"; do
        [ -f "$CONF/$f" ] || continue
        mkdir -p "$KEEP_STASH/$(dirname "$f")"
        cp "$CONF/$f" "$KEEP_STASH/$f"
    done
    for f in "${KEEP_DIRS[@]}"; do
        [ -d "$CONF/$f" ] || continue
        mkdir -p "$KEEP_STASH/$(dirname "$f")"
        cp -r "$CONF/$f" "$KEEP_STASH/$f"
    done
}

keep_restore() {
    [ -n "$KEEP_STASH" ] && [ -d "$KEEP_STASH" ] || return 0
    local f restored=0
    for f in "${KEEP_FILES[@]}"; do
        [ -f "$KEEP_STASH/$f" ] || continue
        mkdir -p "$CONF/$(dirname "$f")"
        cp "$KEEP_STASH/$f" "$CONF/$f" && restored=1
    done
    # Каталоги вливаем в свежий, а не заменяем им: в repo-версии лежат свои
    # файлы (логотипы, обои по умолчанию), и `cp -r dir dst` на существующем
    # каталоге положил бы наши внутрь него вложенной копией.
    for f in "${KEEP_DIRS[@]}"; do
        [ -d "$KEEP_STASH/$f" ] || continue
        mkdir -p "$CONF/$f"
        cp -r "$KEEP_STASH/$f/." "$CONF/$f/" && restored=1
    done
    rm -rf "$KEEP_STASH"; KEEP_STASH=""
    [ "$restored" = "1" ] && ok "your settings, shortcuts and wallpapers kept"
    return 0
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
    keep_stash
    for d in panacea hypr foot ghostty kitty fish fastfetch nano; do
        [ -d "$SRC/$d" ] && copy_into_config "$d"
    done
    keep_restore
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
    # Quickshell ищет конфигурации в ~/.config/quickshell/<имя>/shell.qml, и
    # без этой ссылки простое `qs` отвечает «не найдена конфигурация default»
    # — так и было у всех, кто пробовал запустить оболочку руками. Ссылка
    # даёт штатное `qs -c panacea`, не перенося сам конфиг с привычного места.
    mkdir -p "$CONF/quickshell"
    if [ ! -e "$CONF/quickshell/panacea" ]; then
        ln -sfn "$CONF/panacea" "$CONF/quickshell/panacea" \
            && ok "qs -c panacea → $CONF/panacea"
    fi

    # каталог живых обоев: карусель открывает его кнопкой, и он должен
    # существовать ещё до того, как туда что-то положат
    mkdir -p "$CONF/hypr/wallpaper/live"

    # Сочетания клавиш Hyprland читает только из lua/binds_data.lua, а окно
    # Super+/ пишет их в settings.json и пересобирает этот файл. Если файла
    # нет, а в настройках сочетания есть — они молча не работают, и человек
    # видит заводские. Собираем его из settings.json, чтобы источником правды
    # остался один файл, а этот был всего лишь производным от него.
    if [ ! -f "$CONF/hypr/lua/binds_data.lua" ] && [ -f "$CONF/panacea/settings.json" ]; then
        if [ -x "$CONF/panacea/scripts/genbinds.sh" ]; then
            "$CONF/panacea/scripts/genbinds.sh" >/dev/null 2>&1 \
                && ok "keyboard shortcuts rebuilt from your settings"
        fi
    fi

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

        # Дуалбут: без os-prober GRUB видит только Linux, и Windows из меню
        # пропадает — при том, что она никуда не делась. Arch отключает его
        # по умолчанию, поэтому включаем явно.
        if command -v os-prober >/dev/null 2>&1; then
            set_grub_key "$def" GRUB_DISABLE_OS_PROBER "false"
            ok "os-prober enabled — other systems will show up in the menu"
        else
            warn "os-prober not installed — other systems won't appear in the boot menu"
        fi
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
                # Считаем не появившиеся файлы, а закончившиеся загрузки: curl
                # создаёт файл в первый же миг, поэтому по файлам счётчик
                # мгновенно упирался в максимум и потом просто стоял, пока шла
                # настоящая закачка. Живые curl — то, что осталось.
                have=$(find "$dst" -type f 2>/dev/null | wc -l)
                busy=$(pgrep -cx curl 2>/dev/null || echo 0)
                done_now=$(( have - done_before - busy ))
                [ "$done_now" -lt 0 ] && done_now=0
                mb=$(du -sm "$dst" 2>/dev/null | cut -f1)
                printf '\r  %s/%s done · %s MB · %s downloading   ' \
                       "$done_now" "$n" "${mb:-0}" "${busy:-0}"
                sleep 1
            done
        ) &
        mon=$!
        # Счётчик не должен пережить установщик, если тот прервали
        trap 'kill "$mon" 2>/dev/null' EXIT INT TERM
    fi

    # --speed-limit/--speed-time обрывают соединение, которое встало: без них
    # одна повисшая закачка держала установщик все --max-time, и со стороны
    # это выглядело как зависание на последнем файле.
    (cd "$dst" && xargs -P 8 -n 1 curl -sfLO --retry 2 --max-time 120 \
                        --speed-limit 2048 --speed-time 20 < "$list")

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

if [ "$DO_DEPS" = "1" ]; then
    step "Graphics and CPU drivers"
    install_drivers
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

# Яркость монитора на настольной машине. Внутренней матрицы тут нет, и
# единственный путь к подсветке — DDC/CI поверх шины I2C: ядру нужен модуль
# i2c-dev, а пользователю — доступ к /dev/i2c-*. Свежий ddcutil кладёт своё
# udev-правило и выдаёт доступ владельцу сеанса сам, поэтому в группу i2c
# добавляемся только как запасной путь, если правило почему-то не сработало.
#
# На ноутбуке шаг пропускается целиком: там яркость идёт через backlight,
# и трогать модули ядра незачем.
setup_ddc() {
    ls /sys/class/backlight/* >/dev/null 2>&1 && { ok "internal backlight — DDC/CI not needed"; return; }
    command -v ddcutil >/dev/null 2>&1 || { warn "ddcutil missing — no brightness control for the monitor"; return; }

    if ! lsmod 2>/dev/null | grep -q '^i2c_dev'; then
        sudo modprobe i2c-dev 2>/dev/null \
            && ok "i2c-dev loaded" \
            || warn "could not load i2c-dev — brightness over DDC/CI stays unavailable"
    fi
    # чтобы модуль был и после перезагрузки
    if [ ! -f /etc/modules-load.d/i2c-dev.conf ]; then
        echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null 2>&1 \
            && ok "i2c-dev enabled at boot"
    fi
    if getent group i2c >/dev/null 2>&1 && ! id -nG "$USER" | grep -qw i2c; then
        sudo usermod -aG i2c "$USER" 2>/dev/null \
            && warn "added you to the i2c group — takes effect at next login"
    fi

    # Отвечает ли монитор вообще. Ответ важен человеку сразу: DDC/CI на многих
    # мониторах выключен в аппаратном меню, и без этой строки ползунок просто
    # не появился бы без объяснений.
    if ddcutil detect --brief 2>/dev/null | grep -q "I2C bus"; then
        ok "monitor answers over DDC/CI — the brightness slider is in Display"
    else
        warn "no monitor answered over DDC/CI — check that it is enabled in the monitor's own menu"
    fi
}

step "Monitor brightness"
setup_ddc

# Часы в 24 часах. Свои часы оболочка рисует сама, а вот Telegram, календари
# и всё остальное берут формат из LC_TIME — и при en_US показывают 12:02 AM
# вместо 00:02. Меняем ровно формат времени, оставляя язык интерфейса как был:
# en_GB — тот же английский, но 24 часа.
#
# Сессия получает переменную из hypr/lua/env.lua, здесь — системная часть:
# сгенерировать локаль (иначе переменная указывает в никуда) и записать её в
# locale.conf для TTY и входа мимо Hyprland.
setup_time_format() {
    local loc="en_GB.UTF-8"

    if ! locale -a 2>/dev/null | grep -qiE "^en_GB\.?utf-?8$"; then
        if [ -f /etc/locale.gen ]; then
            sudo sed -i "s/^#\s*${loc} UTF-8/${loc} UTF-8/" /etc/locale.gen 2>/dev/null
            grep -q "^${loc} UTF-8" /etc/locale.gen 2>/dev/null \
                || echo "${loc} UTF-8" | sudo tee -a /etc/locale.gen >/dev/null 2>&1
            sudo locale-gen >/dev/null 2>&1
        fi
    fi

    if locale -a 2>/dev/null | grep -qiE "^en_GB\.?utf-?8$"; then
        if ! grep -q "^LC_TIME=" /etc/locale.conf 2>/dev/null; then
            echo "LC_TIME=${loc}" | sudo tee -a /etc/locale.conf >/dev/null 2>&1
        fi
        ok "clocks in 24-hour format (LC_TIME=${loc})"
    else
        warn "could not generate ${loc} — clocks stay in the 12-hour format"
    fi
}

step "Clock format"
setup_time_format

# Курсор. Тему знают три разных места, и пропустить любое — значит получить
# разный курсор в разных окнах: Hyprland рисует его сам (переменные из
# hypr/lua/env.lua), программы на GTK спрашивают gsettings, а всё остальное
# читает ~/.icons/default/index.theme. Ставим во все три.
setup_cursor() {
    local theme="Bibata-Modern-Classic" size=24

    if [ ! -d "/usr/share/icons/$theme" ] && [ ! -d "$HOME/.icons/$theme" ]; then
        warn "cursor theme $theme is missing — the default cursor stays"
        return
    fi

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface cursor-theme "$theme" 2>/dev/null
        gsettings set org.gnome.desktop.interface cursor-size "$size" 2>/dev/null
    fi

    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nName=Default\nComment=Default cursor theme\nInherits=%s\n' \
        "$theme" > "$HOME/.icons/default/index.theme"

    # GTK3 и GTK4 читают ещё и свой ini — без него курсор в диалогах open/save
    # оставался прежним, хотя во всём остальном уже сменился.
    local g
    for g in "$CONF/gtk-3.0/settings.ini" "$CONF/gtk-4.0/settings.ini"; do
        mkdir -p "$(dirname "$g")"
        if [ -f "$g" ] && grep -q '^gtk-cursor-theme-name=' "$g"; then
            sed -i "s|^gtk-cursor-theme-name=.*|gtk-cursor-theme-name=$theme|" "$g"
        else
            grep -q '^\[Settings\]' "$g" 2>/dev/null || echo '[Settings]' >> "$g"
            echo "gtk-cursor-theme-name=$theme" >> "$g"
        fi
    done

    hyprctl setcursor "$theme" "$size" >/dev/null 2>&1
    ok "cursor → $theme"
}

step "Cursor"
setup_cursor

# Оболочка ставит свой config.fish с алиасами (ls → eza, cd → zoxide, c →
# clear) и своей строкой приглашения. Всё это включается только тогда, когда
# fish действительно запускается при входе: у терминалов свои настройки
# оболочки, и в одном окне алиасы были, а в TTY и соседнем терминале — нет.
step "Login shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v fish)" ]; then
    ok "fish is already your login shell"
elif ! command -v fish >/dev/null 2>&1; then
    warn "fish is missing — the shell config and aliases stay unused"
elif ask "Make fish your login shell? (that is where the aliases and the prompt live)"; then
    sudo chsh -s "$(command -v fish)" "$USER" 2>/dev/null \
        && ok "login shell → fish (takes effect at next login)" \
        || warn "could not change the login shell — run: chsh -s $(command -v fish)"
else
    warn "login shell left as is — aliases work only where fish is started by hand"
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

printf '\n%s✓ Done.%s\n' "$OK" "$N"
printf '%sSUPER+A launcher · SUPER+Z quick settings · SUPER+Tab workspaces · SUPER+E files%s\n' "$DIM" "$N"
printf '%sSUPER+I settings · SUPER+/ shortcuts · or hover the pill.%s\n' "$DIM" "$N"

# ------------------------------------------------------------------- reboot
# Половина установленного подхватывается только при новом входе: сессия видит
# новые группы и службы, портал перечитывает окружение, Hyprland — свой
# конфиг с нуля. Возвращаться в наполовину старую сессию и гадать, почему
# что-то не так, — худший первый опыт, чем одна перезагрузка.
#
# При обновлении сюда не доходит: update.sh зовёт установщик с --no-restart.
if [ "$DO_RESTART" = "1" ]; then
    if [ "$ASSUME_YES" = "1" ]; then
        printf '\n%sRebooting in 10 seconds — Ctrl+C to stay.%s\n' "$B" "$N"
        sleep 10 && systemctl reboot
    elif ask $'\nReboot now? Everything comes up clean after it'; then
        systemctl reboot
    else
        printf '%sLog out and back in when convenient.%s\n' "$DIM" "$N"
    fi
fi
