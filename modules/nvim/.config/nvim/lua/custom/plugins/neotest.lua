return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"jfpedroza/neotest-elixir",
	},
	lazy = false,
	keys = {
		{
			"<leader>tt",
			function()
				require("neotest").run.run(vim.fn.expand("%"))
			end,
			desc = "Run File",
		},
		{
			"<leader>tT",
			function()
				require("neotest").run.run(vim.uv.cwd())
			end,
			desc = "Run All Test Files",
		},
		{
			"<leader>to",
			function()
				require("neotest").output.open()
			end,
			desc = "[O]pen test output",
		},
		{
			"<leader>ti",
			function()
				require("neotest").summary.toggle()
			end,
			desc = "Toggle summary",
		},
	},
	config = function()
		require("neotest").setup({
			adapters = {
				require("neotest-elixir"),
			},
			quickfix = {
				enabled = true,
				open = true,
			},
		})
	end,
}
