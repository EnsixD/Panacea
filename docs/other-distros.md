# Ubuntu / Debian compatibility notes for Panacea

*Note: parts of this write-up were drafted with AI assistance while working through the setup.*

Panacea targets and is tested on Arch Linux. This document collects the adjustments needed to run
it on an Ubuntu/Debian base (tested on Ubuntu 24.04 / Linux Mint 22.3). This isn't an attempt at
official support, just a reference for anyone trying the same path.

---

## 1. Quickshell isn't packaged

Ubuntu/Debian don't have Quickshell in their official repos. Building from source is required.

### Dependencies

```bash
sudo apt install -y \
  cmake ninja-build pkg-config clang \
  qt6-base-dev qt6-declarative-dev qt6-shadertools-dev \
  qt6-wayland-dev libqt6svg6-dev \
  qt6-declarative-private-dev qt6-base-private-dev qt6-wayland-private-dev \
  libdrm-dev libwayland-dev wayland-protocols libwayland-bin \
  libxkbcommon-dev libpipewire-0.3-dev \
  spirv-tools libcli11-dev libjemalloc-dev \
  libpam0g-dev libpolkit-agent-1-dev libglib2.0-dev libgbm-dev
```

The `-private-dev` packages are needed because Debian/Ubuntu split Qt's private headers into
separate packages (official Qt builds include them by default). Without them, the build fails
with `Imported target "Qt::QuickPrivate" includes non-existent path`.

### System Qt is too old

Ubuntu 24.04 ships Qt 6.4.2. Quickshell declares Qt 6.6 as the minimum, but in practice some moc
constructs used in the code (`Q_PROPERTY(... READ default ...)`) require a newer version. With
6.4.2 the build fails with `Parse error at "READ"`.

Fix: install a newer Qt in a separate directory (without touching the system one) via
[aqtinstall](https://github.com/miurahr/aqtinstall):

```bash
pip install aqtinstall --break-system-packages
python3 -m aqt install-qt linux desktop 6.7.3 linux_gcc_64 -O ~/Qt -m qtshadertools qtmultimedia
```

### Build

```bash
git clone https://github.com/quickshell-mirror/quickshell.git
cd quickshell

cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH=$HOME/Qt/6.7.3/gcc_64 \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCRASH_HANDLER=OFF -DX11=OFF -DI3=OFF -DI3_IPC=OFF \
  -DSERVICE_PAM=ON -DSERVICE_POLKIT=ON -DSCREENCOPY=ON \
  -DNO_PCH=ON \
  -DINSTALL_QMLDIR=$HOME/Qt/6.7.3/gcc_64/qml

cmake --build build
sudo cmake --install build
```

Things to note:
- `CMAKE_PREFIX_PATH` must point to the downloaded Qt, not the system one.
- `-DNO_PCH=ON` is required with `SERVICE_POLKIT=ON`. Without it, the build fails with
  `error: POSIX thread support was disabled in PCH file but is currently enabled`, a conflict
  between the `-pthread` flags pulled in by glib/gobject (a Polkit dependency) and the shared
  precompiled header, generated without that flag for other targets in the project.
- On low-RAM hardware, limit parallel jobs (`cmake --build build -j2`) and consider adding
  temporary swap.

### Runtime

The resulting binary links against the custom Qt, not the system one. At runtime you need to
export:

```bash
export LD_LIBRARY_PATH="$HOME/Qt/6.7.3/gcc_64/lib:$LD_LIBRARY_PATH"
export QML2_IMPORT_PATH="$HOME/Qt/6.7.3/gcc_64/qml:$QML2_IMPORT_PATH"
export QT_PLUGIN_PATH="$HOME/Qt/6.7.3/gcc_64/plugins:$QT_PLUGIN_PATH"
```

On Hyprland, the cleanest approach is setting these as session-scoped environment variables
(`env = NAME,value` in the classic `.conf`, or the equivalent in whatever config syntax you use)
rather than in a global `.bashrc`/`.zshrc`. This avoids other system Qt applications picking up
the wrong version.

---

## 2. foot in the repos is too old

Panacea's theme uses `[colors-dark]` (a color-scheme-aware section) and `cursor.blink-rate`,
features not present in `foot` 1.16.2 (the version shipped in Ubuntu 24.04). Symptom: the terminal
opens with config parsing errors and falls back to default font/colors.

Build from source (a lightweight project, no Qt dependency, compiles in a few minutes):

```bash
sudo apt install -y meson ninja-build scdoc \
  libwayland-dev wayland-protocols \
  libxkbcommon-dev libfontconfig1-dev libfreetype-dev \
  libpixman-1-dev libutf8proc-dev

git clone --recursive https://codeberg.org/dnkl/foot.git
cd foot
meson setup build --buildtype=release -Db_lto=true
ninja -C build
sudo ninja -C build install
```

`tllist` and `fcft` (dependencies not packaged on Ubuntu) are downloaded automatically by Meson as
subprojects.

---

## 3. Packages with no direct equivalent

| Arch/AUR package | Ubuntu/Debian alternative |
|---|---|
| `bat` | package is called `bat`, but the binary is `batcat`, needs a manual alias (`ln -sf /usr/bin/batcat ~/.local/bin/bat`) |
| `yazi` | not in the repos; via `cargo install --force yazi-build` (not `yazi-fm`/`yazi-cli` directly, those fail with an explicit error pointing to the correct wrapper) |
| `mpvpaper` | not in the repos (AUR-only on Arch); simple build from source, no Qt dependency: `github.com/GhostNaN/mpvpaper`, `meson setup build && ninja -C build && sudo ninja -C build install` |
| `bibata-cursor-theme-bin` | not in the repos; not addressed in this setup, you can keep whatever cursor theme is already on the system |

---

## 4. NetworkManager / iwd conflict

Panacea's Wi-Fi script (`panacea/scripts/wifi.sh`) talks directly to `iwd` via `iwctl` and is
written assuming NetworkManager isn't present, typical of a minimal Arch install, but not the
default on Ubuntu/Mint (where NetworkManager manages Wi-Fi out of the box).

Running both side by side causes a sequence of non-obvious issues:

1. `iwctl station ... connect` fails with `Operation aborted`. NetworkManager/wpa_supplicant
   compete with iwd for the interface, even after marking the device `unmanaged` in
   NetworkManager.
2. With the interface set to `unmanaged`, the connection authenticates but never gets an IP
   (`NO-CARRIER`). Nobody does DHCP on iwd's behalf anymore.
3. Even after enabling iwd's internal DHCP (`EnableNetworkConfiguration=true` in
   `/etc/iwd/main.conf`), iwd's log shows `netconfig agent call returned
   org.freedesktop.NetworkManager.Device.InvalidConnection`. NetworkManager registers itself as
   the system-wide netconfig agent for iwd regardless of the individual device's `unmanaged`
   state, and rejects the request.

**Fix applied** (a bit drastic, but consistent with the script's own assumption): remove
NetworkManager from the equation entirely, leaving iwd for Wi-Fi and systemd-networkd for
Ethernet.

```bash
sudo systemctl stop wpa_supplicant
sudo systemctl disable wpa_supplicant
sudo systemctl disable --now NetworkManager

sudo mkdir -p /etc/iwd
printf '[General]\nEnableNetworkConfiguration=true\n' | sudo tee /etc/iwd/main.conf
sudo systemctl restart iwd

sudo mkdir -p /etc/systemd/network
printf '[Match]\nName=en*\n\n[Network]\nDHCP=yes\n' | sudo tee /etc/systemd/network/20-wired.network
sudo systemctl enable --now systemd-networkd
sudo systemctl enable --now systemd-resolved
```

(the `Name=en*` match instead of the exact interface name is useful if you're using USB-Ethernet
adapters whose name/MAC changes between sessions)

A less drastic alternative, telling NetworkManager to explicitly ignore only the Wi-Fi interface
while keeping it for Ethernet, was tried but didn't fix issue 3, since NetworkManager's netconfig
agent registration for iwd doesn't appear to be gated by per-device state.

---

## 5. `install.sh` behavior on Ubuntu

The script is written for Arch (pacman/AUR), but most of the logic after the dependency check
(backups, file copying, `systemctl enable/mask`) is distro-agnostic. Observed behavior:

- `install_deps()`: if `pacman` isn't present, it warns and continues without blocking. Still
  worth running with `--no-deps` after manually installing packages (see section 3 above).
- The `--print-obsolete` flag exits immediately if `pacman` isn't present, harmlessly.
- GRUB theme: only modifies specific keys in `/etc/default/grub` (with an automatic backup) and
  regenerates `grub.cfg` via `grub-mkconfig`. It never calls `grub-install`, so the operation is
  standard and reversible even on a dual-boot Ubuntu system.
- SDDM theme: self-disables if `sddm` isn't installed (the default on many Ubuntu-based distros
  using LightDM). No display manager conflict.

---

## Possibly distro-independent bug

While adapting this, it turned out `hypr/lua/programs.lua` and some binds in
`hypr/lua/keybindings.lua` (volume/brightness) contain paths hardcoded to the original install's
home directory (`/home/ensi/...`). The `personalize_paths()` mechanism in `install.sh` fixes most
of these during installation, but it's worth checking
`grep -rn "/home/ensi" ~/.config/hypr ~/.config/panacea` after a fresh install, regardless of which
distro you're on.
