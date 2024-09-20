return {
	"tpope/vim-fugitive",
	config = function()
		vim.api.nvim_create_user_command("Gc", "G checkout -b <args> HEAD", { nargs = 1 })
		vim.api.nvim_create_user_command("Gco", "G checkout -b <args> origin", { nargs = 1 })
		vim.api.nvim_create_user_command("Gpo", "G push -u origin HEAD <args>", { nargs = "*" })
		vim.api.nvim_create_user_command("Gpof", "G push -u origin HEAD --force-with-lease", {})
		vim.api.nvim_create_user_command("Gfo", "G fetch origin", {})
		vim.api.nvim_create_user_command("Gro", "G rebase origin/main", {})
		vim.api.nvim_create_user_command("Gri", "G rebase --interactive origin/main", {})
		vim.api.nvim_create_user_command("Gra", "G rebase --abort", {})
		vim.api.nvim_create_user_command("Grc", "G rebase --continue", {})
	end,
}
