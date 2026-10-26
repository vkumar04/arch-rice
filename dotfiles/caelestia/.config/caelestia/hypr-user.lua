-- Caelestia user config, loaded last. Hardware-only tweaks for the Framework Laptop 13 Pro.

-- 13.5" 2880x1920 panel: Caelestia's default scale of 1 is unreadably small.
-- 1.6 → 1800x1200 effective. Try 2 for bigger, 1.5 for more space.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.6 })
