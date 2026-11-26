local M = {}

local function register(name, title, description, choose_file)
  rex.action{
    name = name, title = title, category = "Pane",
    description = description,
    run = function(ctx)
      if not ctx.block_id then error(name .. ": no focused terminal", 0) end
      local options = { command = {
        "/run/current-system/sw/bin/rex-scrollback-picker", ctx.block_id,
      } }
      if choose_file then
        local process = rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id })
        local cwd = process and ((process.foreground or {}).cwd or (process.child or {}).cwd)
        if not cwd or cwd == "" then error(name .. ": no focused terminal working directory", 0) end
        options.cwd = cwd
        options.command[3] = "--file"
      end
      -- Rex 1408 clips floating terminal content at nonzero vertical origins.
      local layer, err = rex.session.new_layer{
        bounds = { 0, 0, 1, choose_file and 1 or 0.5 }, focus = true,
        layout = rex.layout.block{
          flavor = "com.superlogical.terminal.shell",
          options = options,
        },
      }
      if not layer then error(name .. ": " .. tostring(err), 0) end
      -- The picker runs in the float; waiting here would block client input.
      return layer
    end,
  }
end

function M.setup()
  register("open_url", "Open URL…", "Pick URLs from the focused terminal with fzf and open them.")
  register("open_file", "Open File in Editor…", "Pick files from the focused terminal and open one in $EDITOR.", true)
end

return M
