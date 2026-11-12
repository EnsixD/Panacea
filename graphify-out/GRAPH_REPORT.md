# Graph Report - Panacea  (2026-11-12)

## Corpus Check
- 84 files · ~56,073 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 127 file(s) not represented in the graph (top: .qml 71, .fish 16, .conf 16)

## Summary
- 384 nodes · 661 edges · 60 communities (23 shown, 37 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cc583623`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- install.sh
- os
- brightness.sh
- browser_pw.py
- update.sh
- wifi.sh
- make_assets.py
- record.sh
- start.sh
- files.sh
- live_wallpaper.sh
- agents.sh
- bootos.sh
- vibrance.sh
- locale.sh
- smart_volume.sh
- switch_theme.sh script
- battery_mode.sh
- lock.sh
- shot.sh
- thumbs.sh
- vault.sh
- voxtype.sh
- palette.sh script
- manifest.sh script
- media.sh
- ocr.sh
- props.sh
- themes.sh
- weather.sh
- weather_forecast.sh
- smart_brightness.sh
- pack_workspaces.sh
- start_zen_bg.sh
- wallpaper.sh
- ai.sh
- audio_streams.sh
- browser.sh
- captive.sh
- capture.sh
- check.sh
- desktop_hidden.sh
- focusapp.sh
- monitors.sh
- openmedia.sh
- power.sh
- smart_close.sh
- sysload.sh
- shotcrop.py

## God Nodes (most connected - your core abstractions)
1. `ok()` - 31 edges
2. `warn()` - 25 edges
3. `install.sh script` - 22 edges
4. `install_configs()` - 14 edges
5. `record.sh script` - 10 edges
6. `cmd_apply()` - 10 edges
7. `step()` - 9 edges
8. `install_deps_debian()` - 9 edges
9. `install_deps()` - 9 edges
10. `collect_firefox()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `install.sh script` --calls--> `palette.sh script`  [EXTRACTED]
  install.sh → hypr/scripts/palette.sh
- `install.sh script` --calls--> `switch_theme.sh script`  [EXTRACTED]
  install.sh → hypr/scripts/switch_theme.sh
- `install_configs()` --calls--> `genbinds.sh script`  [EXTRACTED]
  install.sh → panacea/scripts/genbinds.sh
- `install_configs()` --calls--> `geninput.sh script`  [EXTRACTED]
  install.sh → panacea/scripts/geninput.sh
- `install_configs()` --calls--> `genmonitors.sh script`  [EXTRACTED]
  install.sh → panacea/scripts/genmonitors.sh

## Import Cycles
- None detected.

## Communities (60 total, 37 thin omitted)

### Community 0 - "install.sh"
Cohesion: 0.13
Nodes (47): ask(), aur_helper(), backup(), check_aur_helper(), check_deps(), check_grub_prefix(), copy_into_config(), detect_distro() (+39 more)

### Community 1 - "os"
Cohesion: 0.07
Nodes (13): check_amd_s2idle(), DistroPackage, get_distro(), is_root(), PipxPackage, read_file(), relaunch_sudo(), agent_is_in_focused_window() (+5 more)

### Community 2 - "brightness.sh"
Cohesion: 0.22
Nodes (20): backend(), backlight_dev(), bl_get(), bl_set(), clamp(), cmd_detect(), cmd_get(), cmd_list() (+12 more)

### Community 3 - "browser_pw.py"
Cohesion: 0.26
Nodes (8): chromium_decrypt(), chromium_key(), collect_chromium(), collect_firefox(), firefox_profiles(), log(), main(), NSS

### Community 4 - "update.sh"
Cohesion: 0.25
Nodes (16): changelog_filter(), cmd_apply(), cmd_check(), current(), current_version(), fetch_repo(), have(), remote_info() (+8 more)

### Community 6 - "wifi.sh"
Cohesion: 0.37
Nodes (13): active_iface(), autoconnect(), current_quality(), current_ssid(), find_available_known(), iface_list(), known_iwd(), known_networks() (+5 more)

### Community 7 - "make_assets.py"
Cohesion: 0.16
Nodes (5): build_background(), build_boxes(), cover(), rounded(), slice9()

### Community 8 - "record.sh"
Cohesion: 0.35
Nodes (10): attempt(), default_mic(), default_monitor(), finalize(), find_recorder(), have_enc(), read_state(), record.sh script (+2 more)

### Community 9 - "start.sh"
Cohesion: 0.22
Nodes (8): ELECTRON_OZONE_PLATFORM_HINT, GDK_BACKEND, MOZ_ENABLE_WAYLAND, QT_QPA_PLATFORM, start.sh script, XDG_CURRENT_DESKTOP, XDG_SESSION_DESKTOP, XDG_SESSION_TYPE

### Community 10 - "files.sh"
Cohesion: 0.42
Nodes (8): dirty_kb(), flush_to_disk(), on_cancel(), progress_kill(), progress_start(), py(), files.sh script, uniq_target()

### Community 11 - "live_wallpaper.sh"
Cohesion: 0.52
Nodes (6): live_state(), poster(), resolve(), save_live(), live_wallpaper.sh script, still_state()

### Community 12 - "agents.sh"
Cohesion: 0.38
Nodes (4): add(), claude_json(), iso_ms(), agents.sh script

### Community 13 - "bootos.sh"
Cohesion: 0.52
Nodes (5): boot_into(), grub_cmd(), list_efi(), list_grub(), bootos.sh script

### Community 14 - "vibrance.sh"
Cohesion: 0.48
Nodes (5): apply(), cur(), set_shader(), vibrance.sh script, write_shader()

### Community 15 - "locale.sh"
Cohesion: 0.60
Nodes (5): cmd_get(), cmd_list(), cmd_set(), locale.sh script, want_locale()

### Community 16 - "smart_volume.sh"
Cohesion: 0.60
Nodes (3): cur_pct(), set_pct(), smart_volume.sh script

### Community 17 - "switch_theme.sh script"
Cohesion: 0.70
Nodes (4): current(), hyprpaper_new_format(), resolve(), switch_theme.sh script

### Community 18 - "battery_mode.sh"
Cohesion: 0.83
Nodes (3): disable_battery(), enable_battery(), battery_mode.sh script

### Community 19 - "lock.sh"
Cohesion: 0.67
Nodes (3): QSG_RENDER_LOOP, lock.sh script, step()

### Community 20 - "shot.sh"
Cohesion: 0.83
Nodes (3): cleanup(), ipc(), shot.sh script

### Community 21 - "thumbs.sh"
Cohesion: 0.83
Nodes (3): make_lockbg(), make_thumb(), thumbs.sh script

### Community 23 - "voxtype.sh"
Cohesion: 0.83
Nodes (3): find_vox(), ipc(), voxtype.sh script

### Community 59 - "shotcrop.py"
Cohesion: 0.29
Nodes (5): die(), encode_png(), main(), parse_geom(), read_ppm()

## Knowledge Gaps
- **8 isolated node(s):** `XDG_CURRENT_DESKTOP`, `XDG_SESSION_DESKTOP`, `XDG_SESSION_TYPE`, `QT_QPA_PLATFORM`, `GDK_BACKEND` (+3 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 111 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **37 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `install.sh script` connect `install.sh` to `palette.sh script`, `switch_theme.sh script`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `XDG_CURRENT_DESKTOP`, `XDG_SESSION_DESKTOP`, `XDG_SESSION_TYPE` to the rest of the system?**
  _8 weakly-connected nodes found - possible missing edges._
- **Should `install.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.13046757164404224 - nodes in this community are weakly interconnected._
- **Why does `install_configs()` connect `install.sh` to `manifest.sh script`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `os` be split into smaller, more focused modules?**
  _Cohesion score 0.06787330316742081 - nodes in this community are weakly interconnected._
- **Should `hyprland.lua` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._