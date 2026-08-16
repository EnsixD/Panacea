hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name  = "no-gaps-wtv1",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name  = "no-gaps-f1",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name  = "blueberry",
    match = { class = "blueberry.py" },
    float = true,
    size  = "400 500",
    move  = "(monitor_w-410) 35",
})

hl.window_rule({
    name  = "calculator",
    match = { class = "org.gnome.Calculator" },
    float = true,
    size  = "400 500",
    move  = "(monitor_w-410) 95",
})

hl.window_rule({
    name  = "file-dialogs",
    match = { title = "^(Apri file|Open File|Salva come|Save As|Sfoglia|Library)$" },
    float = true,
    size  = "800 500",
    center = true,
})

hl.window_rule({
    name  = "portal-gtk",
    match = { class = "xdg-desktop-portal-gtk" },
    float = true,
    size  = "900 600",
    center = true,
})

hl.window_rule({
    name  = "spotify",
    match = { class = "^(Spotify|spotify)$" },
    float = true,
    size  = "800 600",
    center = true,
    workspace = "special:magic silent",
})

-- Терминал теперь тайлится как обычное окно:
-- первый занимает весь экран, второй встаёт рядом (layout dwindle).
-- Старое правило принудительно делало его плавающим 850x650 по центру.

-- "Terminal Cascade" удалён: он делал плавающими уже открытые терминалы
-- при каждом новом окне и ломал нормальный тайлинг.

-- Прозрачность терминала. Значение пишет оболочка (ползунок в Appearance)
-- в lua/term_data.lua; файла может не быть — тогда правила просто нет и
-- терминал остаётся непрозрачным.
--
-- Правилом компоновщика, а не alpha в foot.ini: сам foot читает конфиг
-- только при запуске, и ползунок не менял бы ничего в уже открытых окнах.
-- Правило же применяется сразу, ко всем сразу.
local ok_term, term = pcall(require, "lua.term_data")
if ok_term and term and term.opacity and term.opacity < 1 then
    hl.window_rule({
        name    = "panacea-term-opacity",
        match   = { class = "^(footclient|foot)$" },
        opacity = term.opacity,
    })
end
