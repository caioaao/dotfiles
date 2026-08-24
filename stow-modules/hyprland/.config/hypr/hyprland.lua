-- Hyprland config (Lua).
-- Migrated from hyprland.conf (hyprlang) for Hyprland 0.55+.
-- https://wiki.hypr.land/Configuring/Start/

-- ── Monitor ────────────────────────────────────────────────────────────────
-- Fallback rule. nwg-displays (>= 0.4.3) writes ~/.config/hypr/monitors.lua,
-- which overrides this when present.
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- nwg-displays output. monitors.conf is hyprlang and no longer loads;
-- nwg-displays >= 0.4.3 writes monitors.lua alongside it. pcall so a missing
-- file can't kill the config.
pcall(require, "monitors")

-- ── Modules ────────────────────────────────────────────────────────────────
-- Each require runs in its own scope; an error in one module does not stop the
-- others. Order matters only where modules share state (none currently do).
require("modules.autostart")
require("modules.input")
require("modules.appearance")
require("modules.animations")
require("modules.window_rules")
require("modules.keybinds")
