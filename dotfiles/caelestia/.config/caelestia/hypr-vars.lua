-- Caelestia variable overrides (the sanctioned place for changes; never edit ~/.config/hypr).
-- Reference: https://github.com/caelestia-dots/caelestia/blob/main/hypr/variables.lua
return {
  editor          = "zeditor",            -- Zed (Arch packages it as `zeditor`)
  sleepGestureCmd = "systemctl suspend",  -- default is suspend-then-hibernate; zram swap can't hibernate
}
