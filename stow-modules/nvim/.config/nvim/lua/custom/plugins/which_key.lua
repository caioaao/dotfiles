return { -- Useful plugin to show you pending keybinds.
	"folke/which-key.nvim",
	event = "VimEnter",
	---@module 'which-key'
	---@type wk.Opts
	opts = {
		delay = 0,
		icons = { mappings = vim.g.have_nerd_font },
		spec = {
			{ "<leader>s", group = "[S]earch", mode = { "n", "v" } },
			{ "<leader>t", group = "[T]oggle" },
			{ "gr", group = "LSP Actions", mode = { "n" } },
		},
	},
}
