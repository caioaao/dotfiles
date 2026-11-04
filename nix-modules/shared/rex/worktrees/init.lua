-- Repo-owned Rex worktree actions. Picker protocol adapted from rex-worktrunk
-- (haxybaxy, MIT; see LICENSE). Git and hook policy remain Worktrunk's concern.
local M = {}
local directory = assert(debug.getinfo(1, "S").source:gsub("^@", ""):match("^(/.+)/[^/]+$"),
  "worktrees: load this module from an absolute path")
local registry = dofile(directory .. "/sessions.lua")
local options = {
  base = "@", remotes = false, slugify = false,
  script = "/run/current-system/sw/bin/rex-worktree-picker",
}
local layer_id

local function fail(message)
  error("worktrees: " .. tostring(message), 0)
end

local function call(method, args)
  local result, err = rex.call(method, args)
  if result == nil then fail(err) end
  return result
end

local function normalize(path)
  path = path or ""
  if path == "" then fail("missing worktree path") end
  if path:sub(1, 2) == "~/" then path = os.getenv("HOME") .. path:sub(2) end
  local result, err = rex.exec{ options.script, "normalize", path }
  if result == nil or not result.ok then fail(err or result.stderr) end
  return (result.stdout:gsub("\n$", ""))
end

local function is_directory(path)
  local result = rex.exec{ "test", "-d", path }
  return result ~= nil and result.ok
end

local function session_for(path)
  return registry.resolve(path, options.script, function(label)
    return call("session.create", {
      label = label,
      initial_windows = { { layout = rex.layout.block{
        flavor = "com.superlogical.terminal.shell", options = { cwd = path },
      } } },
    }).session_id
  end)
end

local function show(ctx, id)
  if ctx.origin == "key" or ctx.origin == "palette" then
    rex.client.queue("session.select", { session_id = id })
    return
  end
  -- The floating terminal returns through a separate CLI invocation. Requests
  -- from that invocation require the app's Remote Control permission.
  local apps = call("client.list", { kinds = { "app" }, session_id = ctx.session_id })
  if #(apps.clients or {}) == 0 then apps = call("client.list", { kinds = { "app" } }) end
  local last_error
  for _, client in ipairs(apps.clients or {}) do
    local _, err = rex.call("client.perform", {
      client_id = client.client_id, action = "session.select",
      args = { session_id = id }, origin = ctx.origin,
    })
    if err == nil then return end
    last_error = err
  end
  fail(last_error or "no Rex app is connected")
end

function M.go(ctx, path)
  path = normalize(path)
  if not is_directory(path) then fail("not a directory: " .. path) end
  local id, created = session_for(path)
  local ok, err = pcall(show, ctx, id)
  if not ok then
    fail('session "' .. (path:match("[^/]+$") or path)
      .. '" is ready, but the app would not show it: ' .. tostring(err))
  end
  return { session_id = id, path = path, created = created }
end

function M.close(ctx, path, main)
  path = normalize(path)
  local id = registry.resolve(path, options.script)
  if id == nil then return { closed = false } end
  -- Never terminate the viewing session unless presenting main succeeds first.
  if id == ctx.session_id and main and is_directory(main) then M.go(ctx, main) end
  call("session.attach", { session_id = id })
  call("session.destroy", { session_id = id })
  registry.forget(path, id, options.script)
  return { closed = true, session_id = id }
end

local function open(ctx, remove)
  if not ctx.block_id then fail("no focused terminal") end
  local process = rex.block.call("com.superlogical.terminal", "process", { block_id = ctx.block_id })
  local cwd = process and ((process.foreground or {}).cwd or (process.child or {}).cwd)
  if not cwd or cwd == "" then fail("can't tell the working directory of the focused terminal") end
  local command = { options.script, remove and "remove" or "pick" }
  if not remove then
    if options.base then command[#command + 1] = "--base"; command[#command + 1] = options.base end
    if options.remotes then command[#command + 1] = "--remotes" end
    if options.slugify then command[#command + 1] = "--slugify" end
  end
  if layer_id then rex.session.close_layer{ layer_id = layer_id }; layer_id = nil end
  local layer, err = rex.session.new_layer{
    bounds = { 0.15, 0.1, 0.7, 0.8 }, focus = true,
    layout = { block = {
      flavor = "com.superlogical.terminal.shell", label = remove and "worktree remove" or "worktree",
      options = { command = command, cwd = cwd },
    } },
  }
  if layer == nil then fail(err) end
  layer_id = layer.layer_id
  -- Return immediately: waiting for fzf inside a key action blocks app input.
  return layer
end

function M.setup(config)
  for key, value in pairs(config or {}) do
    if options[key] == nil then fail("unknown option: " .. key) end
    options[key] = value
  end
  rex.action{
    name = "worktree", title = "Worktree: switch / create…", category = "Worktree",
    description = "Pick a checkout or branch, or type a new branch name.",
    run = function(ctx) return open(ctx, false) end,
  }
  rex.action{
    name = "worktree_remove", title = "Worktree: remove…", category = "Worktree",
    description = "Remove a non-main checkout and close its entire Rex session.",
    run = function(ctx) return open(ctx, true) end,
  }
  rex.action{
    name = "worktree_go", title = "Open Worktree Session", category = "Worktree",
    args = { path = "string" },
    run = function(ctx, args) return M.go(ctx, args.path) end,
  }
  rex.action{
    name = "worktree_close", title = "Close Worktree Session", category = "Worktree",
    args = { path = "string", main = "string" },
    run = function(ctx, args) return M.close(ctx, args.path, args.main) end,
  }
end

return M
