local programs = {}

programs.terminal = "footclient"
programs.fileManager = "pcmanfm"            -- графический проводник
programs.fileManagerTui = "footclient yazi" -- в терминале, на Super+Shift+E
programs.menu = "/home/ensi/.local/bin/smart_menu.sh"
-- Isola dinamica ingrandita (~1.35) senza toccare lo scale reale del monitor
programs.bar = "qs -c ~/.config/panacea"   -- пилюля
programs.rog = "rog-control-center"
programs.screenshot = 'grim -g "$(slurp)" - | wl-copy'
programs.browser = "firefox"
programs.powermenu = "/home/ensi/.local/bin/smart_powermenu.sh"
programs.lock = "hyprlock"
programs.note = "obsidian"
programs.dock = ""

return programs
