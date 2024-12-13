--- @param trunc_len number truncates component to trunc_len number of chars
--- @param hide_width number hides component when window width is smaller then hide_width
--- return function that can format the component accordingly
local function trunc(trunc_len, hide_width)
	return function(str)
		local win_width = vim.fn.winwidth(0)
		if hide_width and win_width < hide_width then
			return ""
		elseif trunc_len and #str > trunc_len then
			return str:sub(1, trunc_len) .. "..."
		end
		return str
	end
end

return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("lualine").setup({
			extensions = {},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { "filename" },
				lualine_x = { "location" },
				lualine_y = {},
				lualine_z = {},
			},
			inactive_winbar = {},
			options = {
				always_divide_middle = true,
				always_show_tabline = true,
				component_separators = {
					left = "",
					right = "",
				},
				disabled_filetypes = {
					statusline = {},
					winbar = {},
				},
				globalstatus = false,
				icons_enabled = true,
				ignore_focus = {},
				refresh = {
					statusline = 100,
					tabline = 100,
					winbar = 100,
				},
				section_separators = {
					left = "",
					right = "",
				},
				theme = "auto",
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { { "branch", fmt = trunc(10, 60) }, "diff", "diagnostics" },
				lualine_c = { "filename" },
				lualine_x = { "filetype" },
				lualine_y = { "location" },
				lualine_z = {},
			},
			tabline = {},
			winbar = {},
		})
	end,
}
