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
#   ./install.sh --yes        answer yes to every prompt
#
# Whatever already sits at a destination is moved to <name>.bak-<timestamp>
# beside it — nothing is deleted.

set -uo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

DO_DEPS=1
DO_SDDM=1
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --no-deps) DO_DEPS=0 ;;
        --no-sddm) DO_SDDM=0 ;;
        --yes|-y)  ASSUME_YES=1 ;;
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
    "hyprlock|hyprlock|lock screen"
    "hyprsunset|hyprsunset|night colour temperature"
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
    "python3|python|helper scripts"
    "rfkill|util-linux|Bluetooth soft-unblock"
    "openssl|openssl|encrypting the password vault"
    "upower|upower|battery state and the battery page"
    "lsblk|util-linux|disks and removable media in the file manager"
    "cava|cava|the audio spectrum in the pill"
)
FILE_DEPS=(
    "/usr/lib/qt6/qml/QtMultimedia/qmldir|qt6-multimedia|video playback"
    "/usr/lib/qt6/qml/QtQuick/Controls/qmldir|qt6-declarative|UI controls"
)
EXTRA_PKGS=(power-profiles-daemon bluez bluez-utils iwd cava pipewire-audio
            ttf-jetbrains-mono-nerd papirus-icon-theme
            # носители в проводнике: udisks2 монтирует, udiskie делает это
            # автоматически при подключении — без него раздел «Съёмные»
            # появится только после ручного монтирования
            udisks2 udiskie
            # необязательные: без них импорт паролей из браузеров просто
            # пропускает соответствующее семейство, всё остальное работает
            python-secretstorage python-cryptography)
FONT_PKG="ttf-jetbrains-mono-nerd"

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
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then ok "JetBrainsMono Nerd Font"
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
    for d in panacea hypr foot ghostty kitty fish fastfetch nano tofi waybar wob swaylock; do
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
    personalize_paths
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
    # пользователю — switch_theme.sh кладёт туда размытые обои и акцент
    # темы, пилюля дописывает выбранный язык, а sddm только читает.
    sudo mkdir -p /var/lib/panacea
    sudo chown "$(id -un):$(id -gn)" /var/lib/panacea
    sudo chmod 755 /var/lib/panacea

    ok "SDDM login theme installed and selected"
}

# ------------------------------------------------------------------------ run
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

step "Enabling services"
enable_services

if [ "$DO_SDDM" = "1" ] && command -v sddm >/dev/null 2>&1; then
    if ask "Also install the Panacea SDDM login theme? (replaces your current login screen, needs root)"; then
        step "Installing the login theme"; install_sddm
    fi
fi

step "Starting the shell"
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1
    # Прогоняем текущую тему: она раскладывает цвета по терминалам, ставит
    # обои и заодно готовит картинку с акцентом для экрана входа. Без этого
    # login-screen оставался бы на цветах по умолчанию до первой смены темы.
    [ -x "$CONF/hypr/scripts/switch_theme.sh" ] \
        && "$CONF/hypr/scripts/switch_theme.sh" >/dev/null 2>&1
    pkill -x qs >/dev/null 2>&1; sleep 1
    (setsid qs -c "$CONF/panacea" >/dev/null 2>&1 &)
    ok "reloaded Hyprland and started the pill"
else
    warn "Hyprland isn't running here — everything comes up at next login"
fi

printf '\n%s✓ Done.%s Log out and back in for a clean start.\n' "$OK" "$N"
printf '%sSUPER+A launcher · SUPER+Z quick settings · SUPER+I settings · or hover the pill.%s\n' "$DIM" "$N"
