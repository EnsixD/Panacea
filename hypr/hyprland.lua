-- Modular Hyprland Lua Configuration
-- Main Entry Point

require("lua.monitors")
require("lua.env")
require("lua.look_and_feel")
require("lua.input")
require("lua.workspaces")
require("lua.windowrules")
require("lua.keybindings")
require("lua.autostart")
require("lua.permissions")

-- User Custom Configurations (overrides & personal additions)
-- Put your custom setups in ~/.config/hypr/custom/ to keep them across updates!
pcall(require, "custom.env")
pcall(require, "custom.general")
pcall(require, "custom.windowrules")
pcall(require, "custom.keybindings")
pcall(require, "custom.autostart")
pcall(require, "custom.init")
