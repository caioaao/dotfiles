return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true })
			end,
			mode = "",
			desc = "[F]ormat buffer",
		},
	},
	opts = {
		notify_on_error = false,
		default_format_opts = {
			lsp_format = "prefer",
		},
		format_on_save = function(bufnr)
			-- Opt-out: filetypes listed here are never autoformatted on save
			local disabled_filetypes = {}
			if disabled_filetypes[vim.bo[bufnr].filetype] then
				return nil
			end
			return { timeout_ms = 500 }
		end,
		formatters_by_ft = {
			lua = { "stylua" },
			-- Conform can also run multiple formatters sequentially
			-- python = { "isort", "black" },
			--
			-- You can use 'stop_after_first' to run the first available formatter from the list
			-- javascript = { "prettierd", "prettier", stop_after_first = true },
		},
	},
}
