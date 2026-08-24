-- Look and layout: gaps, borders, colors, decoration, dwindle, misc.
hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,
		border_size = 2,
		col = {
			active_border = "rgba(88888aff)",
			inactive_border = "rgba(45475aff)",
		},
		layout = "dwindle",
	},

	misc = {
		disable_hyprland_logo = true,
	},

	decoration = {
		rounding = 6,
		blur = { enabled = false },
		shadow = { enabled = false },
	},

	dwindle = {
		preserve_split = true,
	},
})
