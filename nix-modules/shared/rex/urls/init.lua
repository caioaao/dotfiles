local M = {}

function M.setup()
  rex.action{
    name = "open_url", title = "Open URL…", category = "Pane",
    description = "Pick URLs from the focused terminal with fzf and open them.",
    run = function(ctx)
      if not ctx.block_id then error("open_url: no focused terminal", 0) end
      -- Rex 1408 clips floating terminal content at nonzero vertical origins.
      -- Anchor at the top so the bottom-aligned fzf menu remains visible.
      local layer, err = rex.session.new_layer{
        bounds = { 0, 0, 1, 0.5 }, focus = true,
        layout = rex.layout.block{
          flavor = "com.superlogical.terminal.shell",
          options = { command = {
            "/run/current-system/sw/bin/rex-url-picker", ctx.block_id,
          } },
        },
      }
      if not layer then error("open_url: " .. tostring(err), 0) end
      -- The picker runs in the float; waiting here would block client input.
      return layer
    end,
  }
end

return M
