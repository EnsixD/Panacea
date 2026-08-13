local programs = {}

-- Что чем открывается. Всё, что здесь есть, действительно вызывается из
-- keybindings.lua или autostart.lua: записи, на которые никто не смотрит,
-- разъезжаются с системой молча — так здесь уже висели меню и повермену
-- на скриптах, которых нет в репозитории.
programs.terminal = "footclient"
programs.fileManagerTui = "footclient yazi" -- в терминале, на Super+Shift+E
-- Путь абсолютный, без «~»: exec без шелла тильду не раскрывает, и остров
-- молча не запускался — после входа оставался чёрный экран.
programs.bar = "qs -c " .. os.getenv("HOME") .. "/.config/panacea"   -- пилюля
programs.screenshot = 'grim -g "$(slurp)" - | wl-copy'
programs.browser = "firefox"
programs.lock = "/home/ensi/.config/panacea/scripts/lock.sh"
programs.note = "obsidian"

return programs
