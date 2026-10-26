-- Caelestia user config, loaded last. Framework Laptop 13 Pro tweaks.

-- 13.5" 2880x1920 panel: Caelestia's default scale of 1 is unreadably small.
-- 1.6 → 1800x1200 effective. Try 2 for bigger, 1.5 for more space.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.6 })

-- First login only: apply the color scheme from inside Hyprland so Hyprland's own
-- colors (borders, shadows) follow it too. The installer sets it from a TTY, where
-- the CLI can only theme the shell, GTK, Qt and terminal.
hl.on("hyprland.start", function()
  hl.exec_cmd("f=${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/.fw-scheme-applied; " ..
              "test -f $f || (sleep 3 && caelestia scheme set -n catppuccin -f mocha && touch $f)")
end)
