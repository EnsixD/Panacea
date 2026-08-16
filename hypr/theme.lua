return {
    gaps_in = 5,
    gaps_out = 5,
    border_size = 1,
    -- Рамка активного окна. Красный конец прежнего градиента лез в кадр
    -- полосой под островом и спорил с чёрно-белой оболочкой; здесь он ничего
    -- не обозначал — просто цвет.
    active_border = { colors = { "rgba(ffffffff)","rgba(8a8a8aff)" }, angle = 45 },
    inactive_border = "rgba(2a2a2aaa)",
    rounding = 12,
    rounding_power = 4.0,
    active_opacity = 1.0,
    inactive_opacity = 0.90,
    shadow_enabled = false,
    shadow_range = 4,
    shadow_render_power = 3,
    shadow_color = "rgba(1a1a1aee)",
    blur_enabled = false,
    blur_size = 3,
    blur_passes = 1,
    blur_vibrancy = 0.1696,
}
