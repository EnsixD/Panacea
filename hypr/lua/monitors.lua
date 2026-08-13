-- Экраны.
--
-- Запомненные настройки приезжают сюда из settings.json через
-- panacea/scripts/genmonitors.sh — тем же способом, что и сочетания клавиш.
-- Файла нет (первая установка, чужая машина) — остаётся "preferred", и всё
-- работает как раньше.
--
-- Почему режим задаётся здесь, а не только оболочкой: она применяет его
-- примерно через полсекунды после своего старта, а Qt привязывает таймер
-- анимаций к частоте обновления один раз, когда создаёт первое окно. Монитор
-- в этот момент ещё стоит в "preferred" — по HDMI это сплошь и рядом 60 Гц,
-- даже у панели на 144. В итоге оболочка весь сеанс крутит анимации по 60 Гц
-- на мониторе, который давно переключился. Режим обязан стоять до её запуска.
local ok, saved = pcall(require, "lua.monitors_data")
if not ok or type(saved) ~= "table" then saved = {} end

for _, m in ipairs(saved) do
    hl.monitor({
        output    = m.output,
        mode      = m.mode,
        position  = m.position or "auto",
        scale     = m.scale or 1.0,
        transform = m.transform or 0,
        vrr       = m.vrr or 0,
    })
end

-- Всё остальное, что подключат: разрешение по предпочтению панели.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.0,
})
