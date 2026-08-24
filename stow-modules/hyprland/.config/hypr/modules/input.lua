-- Keyboard, touchpad, and text-entry environment.

-- Cedilla fix: use PT-BR compose tables (dead_acute + c = ç)
hl.env("LC_CTYPE", "pt_BR.UTF-8")
-- Dead keys fix: GTK 4.20+ no longer handles dead keys on Wayland
hl.env("GTK_IM_MODULE", "simple")

hl.config({
	input = {
		kb_layout = "us,us",
		kb_variant = ",intl",
		kb_options = "grp:ctrl_space_toggle",
		follow_mouse = 0,

		touchpad = {
			natural_scroll = true,
			tap_to_click = true, -- was tap-to-click
			drag_lock = 1, -- was bool; now int 0/1/2 (1 = timeout)
		},
	},
})
