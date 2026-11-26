local extract = require("scrollback.extract")

local M = {}

local terminal = "com.superlogical.terminal"
local max_items = 2000 -- rex.ui.pick limit
local page_bytes = 512 * 1024

-- Raising an action error opens a persistent alert in the Rex app.
local function warn(message)
  rex.log("warn", "Scrollback picker: " .. message)
end

local function command_error(result, err)
  if not result then return err end
  if result.ok then return nil end
  if result.stderr ~= "" then return result.stderr end
  if result.signal then return result.signal end
  return "exit status " .. result.code
end

local function capture(block_id)
  local first, err = rex.block.call(terminal, "format", {
    block_id = block_id, unwrap = true, max_bytes = page_bytes,
  })
  if not first then return nil, err end
  if not first.id then return first.content end

  local parts, offset = { first.content }, #first.content
  while offset < first.total do
    local page, page_err = rex.block.call(terminal, "blob_read", {
      block_id = block_id, id = first.id, offset = offset, max_bytes = page_bytes,
    })
    if not page then return nil, page_err end
    parts[#parts + 1] = page.data
    if page.eof then break end
    if #page.data == 0 then return nil, "incomplete terminal scrollback" end
    offset = offset + #page.data
  end
  return table.concat(parts)
end

local function pick(title, items, multiple)
  if #items == 0 then return end
  if not (rex.ui and rex.ui.pick) then
    warn("requires Rex API revision 17 or later")
    return
  end
  local selection, reason, detail = rex.ui.pick{ title = title, items = items, multiple = multiple }
  if selection == nil and reason ~= "cancelled" and reason ~= "timeout" then
    warn(title .. ": " .. (detail or reason))
  end
  return selection
end

local function open_urls(ctx)
  if not ctx.block_id then return end
  local text, err = capture(ctx.block_id)
  if not text then return warn("could not read terminal scrollback: " .. err) end
  local items = extract.urls(text, max_items)
  for _, url in ipairs(pick("Open URLs", items, true) or {}) do
    local result, open_err = rex.exec{ "@urlOpener@", url }
    local failure = command_error(result, open_err)
    if failure then warn("could not open URL: " .. failure) end
  end
end

local function existing_files(text, cwd)
  local candidates = extract.file_candidates(text, cwd, os.getenv("HOME"))
  local items, seen = {}, {}
  local batch_size = 512
  for first = 1, #candidates, batch_size do
    local input, titles = {}, {}
    for i = first, math.min(first + batch_size - 1, #candidates) do
      local item = candidates[i]
      input[#input + 1] = item.path
      titles[item.path] = item.title
    end
    -- POSIX test -f follows symlinks and excludes directories and special files.
    -- Paths cross stdin, never the shell's source or its word parser.
    local result, err = rex.exec({ "/bin/sh", "-c", [[
      while IFS= read -r path; do
        if [ -f "$path" ]; then printf '%s\n' "$path"; fi
      done
    ]] }, { stdin = table.concat(input, "\n") .. "\n" })
    local failure = command_error(result, err)
    if failure then return nil, failure end
    for path in result.stdout:gmatch("[^\n]+") do
      local id = extract.absolute_path(path)
      if not seen[id] then
        seen[id] = true
        items[#items + 1] = { id = id, title = titles[path] }
        if #items == max_items then return items end
      end
    end
  end
  return items
end

local function open_file(ctx)
  if not ctx.block_id then return end
  local process, process_err = rex.block.call(terminal, "process", { block_id = ctx.block_id })
  if not process then return warn("could not inspect focused terminal: " .. process_err) end
  local cwd = (process.foreground or {}).cwd
  if not cwd or cwd == "" then cwd = (process.child or {}).cwd end
  if not cwd or cwd == "" then return warn("no focused terminal working directory") end
  local text, capture_err = capture(ctx.block_id)
  if not text then return warn("could not read terminal scrollback: " .. capture_err) end
  local items, files_err = existing_files(text, cwd)
  if not items then return warn("could not check files: " .. files_err) end
  local path = pick("Open File in Editor", items, false)
  if not path then return end

  local split, split_err = rex.session.new_split{
    anchor_id = ctx.block_id, direction = "horizontal", side = "after", focus = true,
    layout = rex.layout.block{
      flavor = terminal .. ".shell",
      options = {
        cwd = cwd,
        shell = "none",
        -- Read $EDITOR in the terminal's login environment. Lex it as words,
        -- without evaluating substitutions, and pass the selected path as argv.
        command = { "@zsh@", "-lc", [[
          editor=(${(z)EDITOR})
          if (( ! $#editor )); then print -u2 'Set $EDITOR on the Rex server'; exit 1; fi
          exec -- "${(@Q)editor}" "$1"
        ]], "rex-editor", path },
      },
    },
  }
  if not split then return warn("could not open editor pane: " .. split_err) end
  return split
end

function M.setup()
  rex.action{
    name = "open_url", title = "Open URL…", category = "Pane",
    description = "Pick and open URLs from the focused terminal and its scrollback.",
    run = open_urls,
  }
  rex.action{
    name = "open_file", title = "Open File in Editor…", category = "Pane",
    description = "Pick a file from the focused terminal and open it in a new editor pane.",
    run = open_file,
  }
end

return M
