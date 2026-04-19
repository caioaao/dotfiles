return {
	-- NOTE: Comment.nvim removed — Neovim 0.10+ has built-in commenting via `gc`
	{ -- Highlight todo, notes, etc in comments
		"folke/todo-comments.nvim",
		event = "VimEnter",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = { signs = false },
	},
}
