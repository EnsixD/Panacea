hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_variant = ",",
        kb_model   = "",
        -- Alt+Shift переключает раскладку
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            -- natural_scroll = true: содержимое следует за пальцами.
            -- Пальцы вверх => страница листается вниз.
            -- Если ощущается наоборот — поставь false, это единственная строка.
            natural_scroll = true,
            scroll_factor = 1.0,
            disable_while_typing = true,
            tap_to_click = true,
            drag_lock = true,
            clickfinger_behavior = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })
-- 3 пальца вверх -> на весь экран
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.dispatch(hl.dsp.window.fullscreen())
    end
})

-- 3 пальца вниз -> закрыть активное окно
hl.gesture({
    fingers = 3,
    direction = "down",
    action = function()
        hl.dispatch(hl.dsp.window.close())
    end
})

-- 4 пальца вниз -> плавающее окно по центру (был старый жест на 3 пальца)
hl.gesture({
    fingers = 4,
    direction = "down",
    action = function()
        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        hl.dispatch(hl.dsp.window.resize({ x = 850, y = 650, relative = false }))
        hl.dispatch(hl.dsp.window.center())
    end
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
