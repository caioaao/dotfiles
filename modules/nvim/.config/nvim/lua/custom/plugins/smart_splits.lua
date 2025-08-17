-- Reuse <C-w>h/j/k/l to move across Neovim splits AND tmux panes.
-- Requires tmux and Neovim inside tmux.
return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  opts = {
    multiplexer_integration = "tmux",
    default_amount = 5,
  },
  config = function(_, opts)
    require("smart-splits").setup(opts)

    local ss = require("smart-splits")
    -- Override Vim's native window moves so they cross the tmux boundary
    vim.keymap.set("n", "<C-w>h", ss.move_cursor_left,  { silent = true })
    vim.keymap.set("n", "<C-w>j", ss.move_cursor_down,  { silent = true })
    vim.keymap.set("n", "<C-w>k", ss.move_cursor_up,    { silent = true })
    vim.keymap.set("n", "<C-w>l", ss.move_cursor_right, { silent = true })

    -- Keep native <C-w>= for equalize, but also map a convenience to resize
    vim.keymap.set("n", "<C-w><C-h>", ss.resize_left,  { silent = true })
    vim.keymap.set("n", "<C-w><C-j>", ss.resize_down,  { silent = true })
    vim.keymap.set("n", "<C-w><C-k>", ss.resize_up,    { silent = true })
    vim.keymap.set("n", "<C-w><C-l>", ss.resize_right, { silent = true })
  end,
}