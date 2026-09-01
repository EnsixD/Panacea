# Custom Hyprland User Configurations

This directory (`~/.config/hypr/custom/`) is dedicated to your personal Hyprland configurations, custom keybindings, window rules, autostart programs, and environment variables.

---

### 🛡️ Safe from Updates
Everything inside `~/.config/hypr/custom/` is **preserved during dotfiles updates and re-installations**. You can safely tweak and expand your configuration without fear of merge conflicts or losing changes after running `update.sh`.

---

### 📂 File Structure

| Config File (Hyprland standard) | Lua Config (Hyprland Lua) | Description |
| :--- | :--- | :--- |
| `env.conf` | `env.lua` | Environment variables (e.g. NVIDIA flags, Qt/GTK themes, Wayland envs) |
| `execs.conf` | `autostart.lua` | Autostart commands and background daemons (`exec-once`) |
| `general.conf` | `general.lua` | General settings, gaps, borders, layout, decoration, and input overrides |
| `rules.conf` | `windowrules.lua` | Custom window and layer rules (`windowrulev2`, `layerrule`) |
| `keybinds.conf` | `keybindings.lua` | Custom keybindings and shortcuts (`bind = ...`) |
| `user.conf` | `init.lua` | General entry point for any other custom configs or scripts |

---

### ⚡ Execution & Override Order
Files in this folder are sourced **at the very end** of the main Hyprland configuration. This allows you to easily override any default setting or shortcut without modifying core Panacea files.
