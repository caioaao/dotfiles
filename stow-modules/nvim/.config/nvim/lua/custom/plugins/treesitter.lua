return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		-- Install parsers (no-op if already installed)
		require("nvim-treesitter").install({
			"bash", "c", "html", "lua", "luadoc", "markdown", "vim", "vimdoc", "hcl", "elixir",
		})

		-- Enable treesitter highlighting for all filetypes with a parser
		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				if pcall(vim.treesitter.start) then
					-- Use treesitter for folding
					vim.wo[0][0].foldmethod = "expr"
					vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
				end
			end,
		})
	end,
}
