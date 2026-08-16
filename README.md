<div align="center">

<img src="assets/logo-256.png" alt="Panacea Shell" width="160">

# Panacea Shell

**One pill for everything.** A Hyprland desktop where the whole shell is a single
capsule at the edge of the screen.

<a href="https://archlinux.org"><img alt="Arch Linux" src="https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white"></a>
<a href="https://hyprland.org"><img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white"></a>
<a href="https://quickshell.org"><img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-7F7F7F?style=for-the-badge&logo=qt&logoColor=white"></a>
<a href="https://fishshell.com"><img alt="Fish" src="https://img.shields.io/badge/Fish-111111?style=for-the-badge&logo=gnubash&logoColor=white"></a>
<a href="#licence"><img alt="MIT" src="https://img.shields.io/badge/MIT-3b82f6?style=for-the-badge"></a>

</div>

---

No bar, no tray, no scattered popups. Wi‑Fi, Bluetooth, power profiles, the
launcher, notifications, the media player, a file manager, a password manager,
the power menu and the settings all live inside one pill that morphs into
whatever you asked for and flows back when you're done. It hugs its screen edge
with two concave corners, like a hardware notch: no floating rectangle, no gap,
no border — only the content changes.

The island can sit at any edge — top, bottom, left or right — and always opens
towards the centre of the screen. At the side edges it turns vertical and stacks
its text letter under letter, so nothing has to be read with a tilted head.

## Demo



https://github.com/user-attachments/assets/854260b8-e96e-4773-8267-2decab779d6e


<sub>A short tour recorded with the pill's own screen recorder. The same clip is
committed as <code>demo.mp4</code>; the link above is GitHub's own upload, since
it only plays videos inline when they come from its editor rather than from a
file in the repository.</sub>

## Pages

Every panel is the same capsule at a different size, so the whole shell shares
one geometry, one palette and one animation timeline.

| Page | Opens with | What it does |
|---|---|---|
| Quick settings | `Super + Z` | Wi‑Fi, Bluetooth, sound, now playing with transport and seeking straight on the equaliser, recorder, battery, passwords, tray |
| Networks / Bluetooth | `Super + Shift + W` / `+ B` | Scan, connect, pair |
| Notifications | `Super + Shift + N` | Live cards that open what they are about, one history list, do‑not‑disturb |
| Wallpapers | `Super + Shift + T` | Full‑screen carousel with parallax previews, stills and live video |
| Workspaces | `Super + Tab` | Live previews of every workspace, switch from the grid |
| Launcher | `Super + A` | App search + calculator, recents first; also the agent panel and the other systems on the disk |
| Clipboard | `Super + V` | `cliphist` history with search |
| Files | `Super + E` | Bookmarks, disks, sorting, trash, context menu, drag between windows |
| Media | opens a file | Images, GIFs, video — trim and crop |
| Recorder | `Super + P` | FPS, folder, system audio, microphone |
| Passwords | `Super + Shift + P` | Encrypted vault, browser import, save prompts |
| Battery | from quick settings | Power profiles, charge state, capacity and wear |
| Power | `Ctrl + Alt + Del` | Sleep, lock, log out, restart, shut down |
| Settings | `Super + I` | Pill, system, displays, keys — with live mock‑ups |
| Shortcuts | `Super + /` | Every binding in one place, rebindable |

Hovering the pill opens it too — the player if something is playing, quick
settings otherwise. Every page closes with the same key, `Escape`, or a click
outside. Collapsed, it shows day, clock, workspace, layout and battery.

**Settings** has twelve sections, searchable from the top of the panel: *Bar &
Island* (a mock‑up of your desktop with the real island on it, its screen edge
and geometry), *Media*, *Clock & Date*, *Appearance* (palette, fonts, interface
language), *Motion*, *Launcher*, *Notifications*, *Control Center* (the quick
settings tiles, rearranged by dragging), *Lock Screen*, *Display* (resolution,
refresh rate, scale, orientation, VRR, multi‑monitor arrangement, brightness and
digital vibrance), *Mouse* and *System*.

## Dual boot

If this machine has more than one operating system on it, three separate things
here know about that.

**The boot menu is themed.** `grub/panacea/` is a GRUB theme in the same
language as the island — the wallpaper, a capsule highlight on the selected
entry, nothing else. The installer copies it to `/boot/grub/themes/panacea`,
points `/etc/default/grub` at it and regenerates the config. Skip it with
`--no-grub`.

**Other systems are made to show up.** Arch disables `os-prober` by default,
which is why a fresh GRUB config often lists only Linux and quietly loses the
Windows that is still sitting on the disk. The installer sets
`GRUB_DISABLE_OS_PROBER=false` when `os-prober` is installed, and says so if it
is missing.

**You can restart into another system from the launcher.** Open it, type
`windows` — or whatever the system is called — and press Enter. There is no
fixed list of two: `panacea/scripts/bootos.sh` finds what is actually there, so
three systems give three entries and one system gives none at all. Names are
tidied for reading, so `Windows Boot Manager (on /dev/nvme0n1p1)` becomes
`Windows`, while distributions keep their versions.

The choice is **one‑shot**: it sets the next boot only, through `grub-reboot`
(or `BootNext` in EFI variables when GRUB is not the bootloader). Your default
system does not change, and the boot after that comes back here. Touching the
bootloader needs root, so `pkexec` asks for a password — that prompt is also the
confirmation, which is why there is no separate "are you sure". These entries
never appear in an empty launcher and are never remembered as recent: a line
that reboots the machine should not sit one careless Enter away from the browser.

> [!NOTE]
> A theme that copies successfully and a config that regenerates without error
> can still both be ignored. The `grubx64.efi` image carries a **prefix** inside
> it — the directory it reads the config, modules and themes from — and if that
> points somewhere else, everything above lands in a folder the bootloader never
> opens. Nothing reports an error; the menu simply never changes. The classic
> case is an ESP mounted at `/boot` over a non‑empty directory, leaving the
> prefix pointing at the old `/boot/grub` now hidden under the mount point. The
> installer checks for exactly this after regenerating and prints the fix:
> `sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB`.

## Colours and wallpapers

There is **one palette** for the whole system, in `hypr/palette.conf`.
`hypr/scripts/palette.sh` spreads it across the terminal, btop, fish,
neovim and the login screen. Changing the wallpaper never touches the colours —
and never touches a file that Hyprland sources, so your windows are left alone.

## What's inside

| | |
|---|---|
| **Compositor** | [Hyprland](https://hyprland.org), Lua config |
| **Shell** | [Quickshell](https://quickshell.org) — the pill, in QML |
| **CLI** | Fish + eza + zoxide |
| **Terminal** | [foot](https://codeberg.org/dnkl/foot), as a server — `foot --server` starts with the session and `footclient` opens windows instantly |
| **Lock / wallpaper** | the pill's own lock screen, hyprpaper, hyprsunset |
| **Boot / login** | GRUB theme, SDDM theme — both matching the palette |

The pill is also the notification daemon and the polkit agent, so don't run
`mako`, `dunst` or `hyprpolkitagent` alongside it. Only one process can own
`org.freedesktop.Notifications`, and the rival never has to be launched to win —
D‑Bus starts it on the first notification, and from then on it draws them in its
own window instead of the island. The installer masks `dunst` and `mako` for that
reason; `systemctl --user unmask dunst.service` puts one back.

## Install these dotfiles

> [!WARNING]
> **The installer is young.** It has been run on a handful of machines, mostly
> the author's. It backs up everything it replaces as `*.bak-<timestamp>`, but
> mistakes are still possible — back up your own `~/.config` first, and read the
> flags below before running it on a setup you care about.

```bash
git clone https://github.com/EnsixD/Panacea.git
cd Panacea
./install.sh
```

The script checks the dependencies, then checks for an AUR helper — `yay`, `paru`
or `pikaur`. If you have one it says which and moves on; if you have none it
offers to build `yay-bin` there and then, since `quickshell` itself lives in the
AUR. Declining is fine: everything from the repos still installs. It then backs
up anything it would overwrite, copies the configs, enables Bluetooth /
power‑profiles / iwd, spreads the palette across the applications, restores the
wallpaper and warms up its thumbnails. It then offers, one prompt at a time: the
wallpaper pack (about 400 MB, downloaded as plain files), the GRUB boot theme and
the SDDM login theme.

Flags: `--no-deps`, `--no-sddm`, `--no-grub`, `--no-services`, `--no-wallpapers`,
`--no-restart`, `--yes`.

### Updating

Panacea checks GitHub for new commits on its own and offers an **Update** button
in *Settings → System*. If your copy predates that — it was installed before the
updater existed, or `~/.config/panacea/.version` is missing — run the updater by
hand once:

```bash
curl -fsSL https://raw.githubusercontent.com/EnsixD/Panacea/main/panacea/scripts/update.sh | bash -s apply
```

No reinstall, and nothing to do to Hyprland itself. The script clones the repo,
carries your `settings.json`, your keybindings, your wallpapers and anything you
put in `panacea/assets` across the install, reinstalls the configs, records the
version and restarts the shell. Packages, the login theme and the boot theme are
left alone — those are installed once. From then on updates arrive through the
button.

Prefer to do it by hand? Copy `panacea hypr foot fish fastfetch
nano` into `~/.config`, `nano/nanorc` to `~/.nanorc`, `bin/*` to
`~/.local/bin`, then run `hypr/scripts/palette.sh`, `hypr/scripts/switch_theme.sh
--restore` and `hyprctl reload`.

The real config is `hypr/hyprland.lua` with the modules under `hypr/lua/`.
`hypr/hyprland.conf` beside it is a fallback for Hyprland versions that cannot
read Lua configs: they would otherwise come up bare — no bindings, no pill, no
way to open a terminal. It carries only the essentials and makes no attempt to
mirror `lua/`; if something is missing there, the answer is to update Hyprland.

Networking assumes **iwd** (the Wi‑Fi page drives `iwctl` directly — no
NetworkManager). Power profiles go through `power-profiles-daemon` over D‑Bus.
Everything resolves `$HOME` at runtime — no hardcoded paths.

## Layout

```
panacea/   the pill: QML, scripts, settings.json
hypr/      Hyprland (Lua config, palette, wallpapers, scripts)
grub/      boot theme + the script that generates its assets
sddm/      login theme
bin/       standalone helper scripts
fish/      shell config and prompt
foot/      terminal
applications/  desktop entries that make the shell the default handler
fastfetch/ nano/
```

Nothing on a fresh Arch install decides what opens a file, so the fallbacks
decide instead: images end up in the browser and folders in a KDE file manager
that is not otherwise used here. The installer fixes that by pointing images,
video and directories at the shell's own viewer and file manager — they reach
the running instance over its IPC rather than starting a second copy — and
leaves the browser handling what belongs to a browser. Set them by hand with
`xdg-mime default`, or skip the whole step by not running the installer.

Shortcuts live in `panacea/settings.json` and compile into
`hypr/lua/binds_data.lua` from the settings panel; that generated file is
gitignored, and without it the defaults in `keybindings.lua` apply.

## Credits

No wallpaper here is mine — each belongs to its author, and they are bundled only
so a fresh install has something to show. Author of one and want it gone? Open an
issue.

- [matteogini/dotfiles](https://github.com/matteogini/dotfiles) — `ember_stripes.jpg`
  and `misty_peaks.jpg`; the rice this setup grew out of.
- [HyDE](https://github.com/HyDE-Project/HyDE) — `spring_bloom.jpg`, from its
  Graphite Mono theme; `hypr/palette.conf` is derived from it.
- [ilyamiro/shell-wallpapers](https://github.com/ilyamiro/shell-wallpapers) — the
  optional pack the installer offers to download.

Video wallpapers play through [mpvpaper](https://github.com/GhostNaN/mpvpaper);
none are bundled. Drop `.mp4`, `.webm`, `.mkv` or `.mov` into
`~/.config/hypr/wallpaper/live`, or take them from
[DesktopHut](https://www.desktophut.com),
[Wallper](https://wallper.app), [TuxPapers](https://tuxpapers.com) or
[Papyrus](https://github.com/PSGtatitos/papyrus) — each on its own terms.

Interface font: [JetBrains Mono Nerd Font](https://www.nerdfonts.com) (SIL OFL),
with [Material Design Icons](https://pictogrammers.com/library/mdi/) for every
glyph. `assets/logo*.png` is drawn for this project, same licence as the code.

Built on [Hyprland](https://hyprland.org) · [Quickshell](https://quickshell.org) ·
[cava](https://github.com/karlstav/cava) · [cliphist](https://github.com/sentriz/cliphist) ·
[hyprpaper / hyprsunset](https://github.com/hyprwm) ·
[wf-recorder](https://github.com/ammen99/wf-recorder) · [fish](https://fishshell.com)

## Licence

MIT — see [LICENSE](LICENSE). It covers the configs, the QML and the scripts.
Wallpapers, fonts and anything else bundled from elsewhere keep the terms of
their own authors.
