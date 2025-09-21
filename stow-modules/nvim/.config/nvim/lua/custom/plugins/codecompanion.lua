return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"ravitemer/mcphub.nvim",
	},
	opts = {
		strategies = {
			-- Change the default chat adapter
			chat = {
				adapter = "anthropic",
			},
		},
	},
	keys = {
		{ "<leader>ac", ":CodeCompanionChat Toggle<CR>", desc = "Chat [T]oggle" },
		{ "<leader>aa", ":CodeCompanionActions<CR>", desc = "Actions Menu", mode = { "n", "v" } },
		{ "<leader>ai", ":CodeCompanionChat Add<CR>", desc = "Add Code to Chat", mode = "v" },
		{ "<leader>an", ":CodeCompanionChat New<CR>", desc = "New Chat" },
		{ "<leader>al", ":CodeCompanionChat<CR>", desc = "Load Chat" },
		{ "<leader>ar", ":CodeCompanionChat Reset<CR>", desc = "Reset Chat" },
		{ "<leader>as", ":CodeCompanionChat SaveAs<CR>", desc = "Save Chat As" },
		{ "<leader>ax", ":CodeCompanionInline<CR>", desc = "Inline Assistant", mode = "v" },
		{ "<leader>ae", ":CodeCompanionExplain<CR>", desc = "Explain Code", mode = "v" },
		{ "<leader>at", ":CodeCompanionTests<CR>", desc = "Generate Tests", mode = "v" },
		{ "<leader>af", ":CodeCompanionFix<CR>", desc = "Fix Code", mode = "v" },
		{ "<leader>ao", ":CodeCompanionOptimize<CR>", desc = "Optimize Code", mode = "v" },
	},
}
