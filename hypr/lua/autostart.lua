local programs = require("lua.programs")

hl.on("hyprland.start", function ()
  hl.exec_cmd("foot --server")

  local zenBgRule = hl.window_rule({
      name = "zen-background-startup",
      match = { class = "zen" },
      workspace = "special:zenbg silent"
  })

  hl.timer(function()
      -- zen-browser не установлен
      -- hl.exec_cmd("zen-browser")
      hl.timer(function()
          zenBgRule:set_enabled(false)
      end, { timeout = 5000, type = "oneshot" })
  end, { timeout = 2000, type = "oneshot" })

  hl.exec_cmd("hyprpaper")
  hl.exec_cmd(programs.bar)
  hl.exec_cmd(programs.rog)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  -- nm-applet отключён: в системе iwd + systemd-networkd
  -- hl.exec_cmd("nm-applet --indicator")
  -- Агент polkit теперь встроен в пилюлю (PolkitAgent в shell.qml).
  -- Два агента одновременно зарегистрироваться не могут.
  -- hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("hyprsunset -t 5000")
  hl.exec_cmd("/home/ensi/.config/hypr/scripts/switch_theme.sh --restore")
  hl.exec_cmd("rm -f $XDG_RUNTIME_DIR/wob.fifo && mkfifo $XDG_RUNTIME_DIR/wob.fifo")
  hl.exec_cmd("cliphist list | tail -n +501 | cliphist delete")
end)
