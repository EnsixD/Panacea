local theme = require("theme")

-- Стоит ли драйвер NVIDIA. Пара настроек ниже нужна только на нём и на
-- других видеокартах делает хуже, поэтому спрашиваем ядро, а не человека:
-- каталог модуля есть ровно тогда, когда драйвер загружен.
-- Читаем /proc/modules, а не /sys/module/nvidia_drm/parameters/*: последние
-- открыты только для root, и проверка через них у обычного пользователя
-- всегда отвечала бы «не NVIDIA».
local nvidia = (function ()
    local f = io.open("/proc/modules", "r")
    if not f then return false end
    for line in f:lines() do
        if line:match("^nvidia_drm") then f:close(); return true end
    end
    f:close()
    return false
end)()

hl.config({
    general = {
        gaps_in  = theme.gaps_in,
        gaps_out = theme.gaps_out,
        border_size = theme.border_size,
        col = {
            active_border   = theme.active_border,
            inactive_border = theme.inactive_border,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding       = theme.rounding,
        rounding_power = theme.rounding_power,
        active_opacity   = theme.active_opacity,
        inactive_opacity = theme.inactive_opacity,
        shadow = {
            enabled      = theme.shadow_enabled,
            range        = theme.shadow_range,
            render_power = theme.shadow_render_power,
            color        = theme.shadow_color,
        },
        blur = {
            enabled   = theme.blur_enabled,
            size      = theme.blur_size,
            passes    = theme.blur_passes,
            vibrancy  = theme.blur_vibrancy,
        },
    },
    animations = {
        enabled = true,
    },
})

-- Animations are now handled in lua/animations.lua
require("lua.animations").apply()

-- Layout Config
hl.config({
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    scrolling = { fullscreen_on_one_column = true },
    misc = {
        force_default_wallpaper = 0,
        disable_splash_rendering = true,
        disable_hyprland_logo   = true,
        background_color        = "rgb(000000)",
        animate_manual_resizes  = true,
        vrr                     = 1,
    },
    xwayland = { force_zero_scaling = true },
    cursor = {
        sync_gsettings_theme = true,
        inactive_timeout     = 5,
        -- Курсор рисуем сами, а не отдельным слоем видеокарты.
        --
        -- В «авто» на драйвере NVIDIA курсор идёт аппаратным слоем, и его
        -- буфер переносится в KMS на каждое движение — в логе это видно
        -- сплошной лентой «Cursor buffer imported into KMS». Время от времени
        -- перенос застревает, и указатель замирает на секунду-другую, хотя
        -- сама система в этот момент жива.
        --
        -- Программный курсор рисуется вместе с кадром: лишний слой и его
        -- переносы исчезают вовсе. На 144 Гц разницы в задержке не видно —
        -- кадр и так меняется каждые 7 мс.
        no_hardware_cursors = nvidia and true or 2,
    },
})
