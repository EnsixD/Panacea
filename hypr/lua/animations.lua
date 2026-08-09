local animations = {}

function animations.apply()
    -- Curve prese da serpantinum (ilyamiro/serpantinum), rallentate per fluidita'
    hl.curve("myBezier",     { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
    hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1.0}, {0.32, 1.0} } })
    hl.curve("liquid",       { type = "bezier", points = { {0.16, 1.0}, {0.3,  1.0} } })
    -- для жестов: разгон помягче, торможение длиннее — движение читается как «уехало»
    hl.curve("gestureOut",   { type = "bezier", points = { {0.4,  0.0}, {0.2,  1.0} } })
    hl.curve("gestureIn",    { type = "bezier", points = { {0.12, 0.9}, {0.15, 1.0} } })

    -- Окна: popin, но мягче
    hl.animation({ leaf = "windows",    enabled = true, speed = 7, bezier = "myBezier", style = "popin 80%" })
    hl.animation({ leaf = "windowsIn",  enabled = true, speed = 7, bezier = "myBezier", style = "popin 80%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 6, bezier = "liquid",   style = "popin 80%" })
    hl.animation({ leaf = "windowsMove",enabled = true, speed = 6, bezier = "liquid" })

    -- Слои (панель, попапы quickshell): мягкое затухание
    hl.animation({ leaf = "layers",    enabled = true, speed = 6, bezier = "liquid", style = "fade" })
    hl.animation({ leaf = "layersIn",  enabled = true, speed = 6, bezier = "liquid", style = "fade" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 5, bezier = "liquid", style = "fade" })

    hl.animation({ leaf = "fade",      enabled = true, speed = 6, bezier = "liquid" })
    hl.animation({ leaf = "border",    enabled = true, speed = 8, bezier = "liquid" })

    -- Workspace: scorrimento continuo
    hl.animation({ leaf = "workspaces",           enabled = true, speed = 7, bezier = "easeOutQuint", style = "slide" })
    hl.animation({ leaf = "specialWorkspaceIn",   enabled = true, speed = 6, bezier = "liquid", style = "fade" })
    hl.animation({ leaf = "specialWorkspaceOut",  enabled = true, speed = 5, bezier = "liquid", style = "fade" })
end

return animations
