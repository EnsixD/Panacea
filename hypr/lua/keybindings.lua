local p = require("lua.programs")
local mainMod = "SUPER"

-- Переопределения сочетаний из панели настроек (Super+I).
-- Файл генерируется автоматически; если его нет — берутся значения по умолчанию.
local ok, ov = pcall(require, "lua.binds_data")
if not ok or type(ov) ~= "table" then ov = {} end

-- B(id, сочетание по умолчанию, действие [, опции])
-- Пустая строка в переопределении = сочетание отключено.
local function B(id, def, action, opts)
    local combo = ov[id]
    if combo == nil then combo = def end
    if combo == "" then return end
    hl.bind(combo, action, opts)
end

-- Абсолютный путь по той же причине, что и у programs.bar: «~» доживает до
-- qs как есть, если команду запускают не через шелл.
local QS = "qs -c " .. os.getenv("HOME") .. "/.config/panacea ipc call pill "


-- ---------------------------------------------------------------- пилюля
B("pillLauncher", mainMod .. " + A",             hl.dsp.exec_cmd(QS .. "launcher"))
B("overview",     mainMod .. " + Tab",           hl.dsp.exec_cmd(QS .. "overview"))
B("pillControls", mainMod .. " + Z",             hl.dsp.exec_cmd(QS .. "controls"))
B("pillSettings", mainMod .. " + I",             hl.dsp.exec_cmd(QS .. "settings"))
B("pillShortcuts",mainMod .. " + slash",         hl.dsp.exec_cmd(QS .. "shortcuts"))
B("pillWifi",     mainMod .. " + SHIFT + W",     hl.dsp.exec_cmd(QS .. "wifi"))
B("pillBt",       mainMod .. " + SHIFT + B",     hl.dsp.exec_cmd(QS .. "bluetooth"))
B("pillClip",     mainMod .. " + V",             hl.dsp.exec_cmd(QS .. "clipboard"))
B("pillPower",    "CTRL + ALT + delete",         hl.dsp.exec_cmd(QS .. "powermenu"))
B("pillNotif",    mainMod .. " + SHIFT + N",     hl.dsp.exec_cmd(QS .. "notifications"))
B("pillRecord",   mainMod .. " + P",             hl.dsp.exec_cmd(QS .. "record"))
B("pillVault",    mainMod .. " + SHIFT + P",     hl.dsp.exec_cmd(QS .. "passwords"))

-- Голос в текст (voxtype): зажми клавишу — говоришь, отпустил — текст
-- вставляется в активное поле. Одна клавиша, два бинда: нажатие запускает
-- запись, отпускание — расшифровку и вставку. Обёртка voxtype.sh заодно
-- показывает индикатор в острове. По умолчанию — правый Alt. id voxDictate
-- виден в окне Super+/, как остальные сочетания; переопределяется из настроек.
-- Обёрнуто в pcall нарочно: на некоторых версиях Hyprland/hl параметры бинда
-- (release, description) или отпускание модификатора могут не поддерживаться, и
-- голая ошибка здесь роняла ВЕСЬ конфиг Hyprland — сбрасывались все сочетания
-- на аварийные, а следом не поднимался и qs. Пусть в худшем случае отвалится
-- только голосовой ввод, а остальные сочетания останутся на месте.
pcall(function()
    local VOX = os.getenv("HOME") .. "/.config/panacea/scripts/voxtype.sh"
    local combo = ov["voxDictate"]
    if combo == nil or combo == "" or combo == "Alt_R" then
        hl.bind("Alt_R", hl.dsp.exec_cmd(VOX .. " start"), { description = "Voice to text", ignore_mods = true, locked = true })
        hl.bind("Alt_R", hl.dsp.exec_cmd(VOX .. " stop"), { release = true, ignore_mods = true, locked = true })
        hl.bind("code:108", hl.dsp.exec_cmd(VOX .. " start"), { description = "Voice to text", ignore_mods = true, locked = true })
        hl.bind("code:108", hl.dsp.exec_cmd(VOX .. " stop"), { release = true, ignore_mods = true, locked = true })
        hl.bind("ISO_Level3_Shift", hl.dsp.exec_cmd(VOX .. " start"), { description = "Voice to text", ignore_mods = true, locked = true })
        hl.bind("ISO_Level3_Shift", hl.dsp.exec_cmd(VOX .. " stop"), { release = true, ignore_mods = true, locked = true })
    else
        hl.bind(combo, hl.dsp.exec_cmd(VOX .. " start"), { description = "Voice to text", ignore_mods = true, locked = true })
        hl.bind(combo, hl.dsp.exec_cmd(VOX .. " stop"), { release = true, ignore_mods = true, locked = true })
    end
end)

-- Basic binds
-- Буквы в Hyprland регистронезависимы: SUPER+f == SUPER+F
local CLOSE = os.getenv("HOME") .. "/.config/panacea/scripts/smart_close.sh"
B("terminal",     mainMod .. " + T",         hl.dsp.exec_cmd(p.terminal))
B("terminalAlt",  mainMod .. " + Return",    hl.dsp.exec_cmd(p.terminal))
B("closeWindow",  mainMod .. " + Q",         hl.dsp.exec_cmd(CLOSE))
B("browser",      mainMod .. " + F",         hl.dsp.exec_cmd(p.browser))
B("fullscreen",   mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
B("exitHypr",     mainMod .. " + SHIFT + M", hl.dsp.exit())
B("themeSwitch",  mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(QS .. "theme"))
-- окно в «плавающее» и обратно
B("floatToggle",  mainMod .. " + W",         hl.dsp.window.float({ action = "toggle" }))
-- панель настроек: динамический остров раскрывается по центру
B("floatCenter", mainMod .. " + SHIFT + Space", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 800, y = 600, relative = false }))
    hl.dispatch(hl.dsp.window.center())
end)
B("fileManager",  mainMod .. " + E",         hl.dsp.exec_cmd(QS .. "files"))
B("fileManagerTui", mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(p.fileManagerTui))
B("toggleSplit",  mainMod .. " + J",         hl.dsp.layout("togglesplit"))
B("notes",        mainMod .. " + O",         hl.dsp.exec_cmd(p.note))
B("screenshot",   mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(p.screenshot))
B("screenOff",    mainMod .. " + SHIFT + F12", hl.dsp.exec_cmd("brightnessctl s 0"))
hl.bind("mouse:277", hl.dsp.window.close())
-- Super+B удалён вместе с режимом энергосбережения оболочки:
-- профили питания теперь в панели (наведение на пилюлю).


-- Workspace Packing (SUPER+A)
B("packWorkspaces", mainMod .. " + SHIFT + A", function()
    local workspaces = hl.get_workspaces()
    local windows = hl.get_windows()
    local active_ws = hl.get_active_workspace()
    if not workspaces or not windows or not active_ws then return end
    local active_ids = {}
    for _, ws in pairs(workspaces) do
        if ws.id and ws.id > 0 and ws.windows and ws.windows > 0 then
            table.insert(active_ids, ws.id)
        end
    end
    table.sort(active_ids)
    local target = 1
    local curr_ws_id = active_ws.id
    local new_active_ws_id = curr_ws_id
    for _, ws_id in ipairs(active_ids) do
        if ws_id ~= target then
            for _, win in pairs(windows) do
                if win.workspace and win.workspace.id == ws_id then
                    hl.dispatch(hl.dsp.window.move({ workspace = target, follow = false, window = win }))
                end
            end
            if ws_id == curr_ws_id then new_active_ws_id = target end
        end
        target = target + 1
    end
    hl.dispatch(hl.dsp.focus({ workspace = new_active_ws_id }))
end)

-- Movement
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Resize
hl.bind("ALT + right", hl.dsp.window.resize({ x = 30,  y = 0,  relative = true }), { repeating = true })
hl.bind("ALT + left",  hl.dsp.window.resize({ x = -30, y = 0,  relative = true }), { repeating = true })
hl.bind("ALT + up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true })
hl.bind("ALT + down",  hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }), { repeating = true })

-- Workspaces
B("emptyWorkspace", mainMod .. " + Space",   hl.dsp.focus({ workspace = "empty" }))
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end
B("specialWorkspace", mainMod .. " + S",     hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
local HOME = os.getenv("HOME")
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(HOME .. "/.local/bin/smart_volume.sh up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(HOME .. "/.local/bin/smart_volume.sh down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(HOME .. "/.local/bin/smart_volume.sh mute"), { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd(HOME .. "/.local/bin/smart_brightness.sh up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd(HOME .. "/.local/bin/smart_brightness.sh down"), { locked = true, repeating = true })
hl.bind(mainMod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind(mainMod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Switch
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(p.lock), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(p.lock), { locked = true })


-- Пилюля: панели открываются в ней же

-- Пустой submap для захвата сочетаний в панели настроек.
-- Пока он активен, у Hyprland нет ни одного бинда, и клавиши целиком
-- уходят приложению — иначе при попытке назначить сочетание срабатывало
-- уже существующее действие.
hl.define_submap("capture", function()
    -- аварийный выход, если панель почему-то не вернёт обычный режим
    hl.bind("SUPER + SHIFT + Escape",
        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/panacea/scripts/capture.sh off"))
end)

