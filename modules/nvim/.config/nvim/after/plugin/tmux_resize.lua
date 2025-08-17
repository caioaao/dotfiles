-- Keep splits proportional when tmux zooms/unzooms (triggers terminal resize)
vim.opt.equalalways = true

vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    vim.cmd("wincmd =")
    vim.cmd("redraw!")
  end,
  desc = "Equalize windows after external resize (e.g., tmux zoom)",
})

-- Nice-to-have: refresh files when focus returns (needs tmux focus-events on)
vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    pcall(vim.cmd.checktime)
  end,
  desc = "Check for changed files on focus gain",
})