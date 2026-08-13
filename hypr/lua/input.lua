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
            -- drag_lock оставлял кнопку «нажатой» после отпускания пальца:
            -- выделение продолжалось само по себе, пока не тапнешь ещё раз
            drag_lock = false,
            clickfinger_behavior = true,
        },
    },
})

-- ---------------------------------------------------------------- жесты
--
-- Используем ВСТРОЕННЫЕ действия Hyprland, а не свои Lua-обработчики.
-- Разница принципиальная: обработчик срабатывает один раз, когда пальцы уже
-- отпущены, поэтому окно до последнего стояло на месте. Встроенные жесты
-- (CCloseTrackpadGesture, CFullscreenTrackpadGesture и другие) обновляются
-- на каждом движении, и окно едет за пальцами в реальном времени.
--
-- Обратный ход тоже работает: не довёл жест до конца — окно вернётся на место.

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })

-- 3 пальца вниз -> окно уезжает вниз за пальцами и закрывается
hl.gesture({ fingers = 3, direction = "down", action = "close" })

-- 3 пальца вверх -> разворачивается на весь экран
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })

-- 4 пальца вниз -> открепить окно и таскать его
hl.gesture({ fingers = 4, direction = "down", action = "float" })

-- Блок hl.device({ name = "epic-mouse-v1", ... }) убран намеренно: это
-- устройство из примера в стоковом конфиге Hyprland, которого нет ни у кого.
-- Зато настройка устройства перебивает общую — и у того, чья мышь однажды
-- назвалась бы так же, ползунок скорости в настройках молча ничего не делал
-- бы. Скорость и разгон теперь живут в окне настроек (раздел Mouse).
