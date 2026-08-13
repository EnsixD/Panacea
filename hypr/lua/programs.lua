local programs = {}

-- Что чем открывается. Всё, что здесь есть, действительно вызывается из
-- keybindings.lua или autostart.lua: записи, на которые никто не смотрит,
-- разъезжаются с системой молча — так здесь уже висели меню и повермену
-- на скриптах, которых нет в репозитории.
programs.terminal = "footclient"
programs.fileManagerTui = "footclient yazi" -- в терминале, на Super+Shift+E
-- Путь абсолютный, без «~»: exec без шелла тильду не раскрывает, и остров
-- молча не запускался — после входа оставался чёрный экран.
--
-- QSG_RENDER_LOOP=threaded — не украшение, а частота кадров. С драйвером
-- NVIDIA Qt сам выбирает «basic», а тот крутит анимации от таймера в 16 мс,
-- то есть ровно 60 кадров, каким бы ни был монитор: на 144 Гц раскрытие
-- острова заметно ступенчатое. Threaded берёт такт от vsync и идёт на
-- частоте экрана (на 144 Гц — 6.94 мс на кадр).
programs.bar = "env QSG_RENDER_LOOP=threaded qs -c "
               .. os.getenv("HOME") .. "/.config/panacea"   -- пилюля
programs.screenshot = 'grim -g "$(slurp)" - | wl-copy'
programs.browser = "firefox"
programs.lock = "/home/ensi/.config/panacea/scripts/lock.sh"
programs.note = "obsidian"

return programs
