return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local parsers = {
			"bash", "c", "diff", "html", "lua", "luadoc", "markdown", "markdown_inline",
			"query", "vim", "vimdoc", "hcl", "elixir",
		}
		require("nvim-treesitter").install(parsers)

		---@param buf integer
		---@param language string
		local function treesitter_try_attach(buf, language)
			if not vim.treesitter.language.add(language) then
				return
			end
			vim.treesitter.start(buf, language)
			-- Use treesitter for folding
			vim.wo[0][0].foldmethod = "expr"
			vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
			-- Enable treesitter-based indentation if available
			local has_indent_query = vim.treesitter.query.get(language, "indents") ~= nil
			if has_indent_query then
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end
		end

		local available_parsers = require("nvim-treesitter").get_available()

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local buf, filetype = args.buf, args.match
				local language = vim.treesitter.language.get_lang(filetype)
				if not language then
					return
				end

				local installed_parsers = require("nvim-treesitter").get_installed("parsers")
				if vim.tbl_contains(installed_parsers, language) then
					treesitter_try_attach(buf, language)
				elseif vim.tbl_contains(available_parsers, language) then
					-- Auto-install missing parser and enable after installation
					require("nvim-treesitter").install(language):await(function()
						if vim.api.nvim_buf_is_valid(buf) then
							treesitter_try_attach(buf, language)
						end
					end)
				else
					-- Try to enable in case the parser exists but is not from nvim-treesitter
					treesitter_try_attach(buf, language)
				end
			end,
		})
	end,
}
