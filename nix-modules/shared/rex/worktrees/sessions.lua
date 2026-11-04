-- Session IDs own checkouts; labels are only the shortest useful path suffix.
-- Each running Rex server has a separate registry, shared by config and CLI Lua.
local M = {}

local function call(method, args)
  local result, err = rex.call(method, args)
  if result == nil then error("worktrunk: " .. tostring(err), 0) end
  return result
end

local function execute(script, command, scope)
  local result, err = rex.exec{ script, command, scope }
  if result == nil or not result.ok then
    error("worktrunk: " .. (result and result.stderr or tostring(err)), 0)
  end
  return (result.stdout:gsub("\n$", ""))
end

-- Lua 5.1 has no utf8 library. Cut only at UTF-8 character boundaries.
local function prefix(text, count)
  local position = 1
  for _ = 1, count do
    if position > #text then return text end
    local byte = text:byte(position)
    position = position + (byte < 128 and 1 or byte < 224 and 2 or byte < 240 and 3 or 4)
  end
  return text:sub(1, position - 1)
end

local function bounded(text, discriminator)
  text = text:gsub("%c", "?")
  if prefix(text, 128) == text and not discriminator then return text end
  local suffix = discriminator and (" [" .. discriminator .. "]") or "…"
  return prefix(text, 128 - #suffix) .. suffix
end

local function suffix_matches(path, suffix)
  if suffix:sub(1, 1) == "/" then return path == suffix end
  return path == suffix or path:sub(-#suffix - 1) == "/" .. suffix
end

local function shortest(path, entries, native_labels)
  local candidate = path:match("[^/]+$") or "/"
  while true do
    local conflict = native_labels[candidate]
    for other in pairs(entries) do
      if other ~= path and suffix_matches(other, candidate) then conflict = true; break end
    end
    if not conflict or candidate == path then return candidate end
    local start = #path - #candidate
    local parent = path:sub(1, start - 1):match("[^/]+$")
    candidate = parent and (parent .. "/" .. candidate) or path
  end
end

local function labels(entries, live)
  local managed, native, ordered = {}, {}, {}
  for path, id in pairs(entries) do managed[id] = true; ordered[#ordered + 1] = path end
  for id, session in pairs(live) do
    if not managed[id] then native[session.label] = true end
  end
  table.sort(ordered)
  local used, result = {}, {}
  for name in pairs(native) do used[name] = true end
  for _, path in ipairs(ordered) do
    local id = entries[path]
    local raw = shortest(path, entries, native)
    local name = bounded(raw)
    if name ~= raw or used[name] then name = bounded(raw, id:match("[^:]+$") or id) end
    local n = 1
    while used[name] do
      n = n + 1
      name = bounded(raw, (id:match("[^:]+$") or id) .. ":" .. n)
    end
    used[name], result[id] = true, name
  end
  return result
end

local function read_entries(file, live, script, scope)
  local handle, err = io.open(file, "r")
  -- Rex's Lua file errors do not expose a numeric errno.
  local missing = false
  if not handle then
    local exists = rex.exec{ script, "registry-exists", scope }
    missing = exists ~= nil and exists.code == 1
  end
  local entries
  if handle then
    local contents = handle:read("*a")
    handle:close()
    local data = rex.json.decode(contents)
    if type(data) ~= "table" or data.version ~= 1 or type(data.entries) ~= "table" then
      error("worktrunk: invalid session registry: " .. file, 0)
    end
    entries = data.entries
  elseif missing then
    -- One-time cutover from the previously reserved full-path labels. Ordinary
    -- native sessions, even those with a matching basename, are never adopted.
    entries = {}
    for id, session in pairs(live) do
      local path = session.label:match("^wt:(/.*)$")
      if path then
        if entries[path] then error("worktrunk: ambiguous legacy identity: " .. path, 0) end
        entries[path] = id
      end
    end
  else
    error("worktrunk: cannot read session registry: " .. tostring(err), 0)
  end
  local seen = {}
  for path, id in pairs(entries) do
    if type(path) ~= "string" or path:sub(1, 1) ~= "/" or type(id) ~= "string" then
      error("worktrunk: invalid session registry entry: " .. file, 0)
    end
    if not live[id] then entries[path] = nil
    elseif seen[id] then error("worktrunk: multiple checkouts own session " .. id, 0)
    else seen[id] = true end
  end
  return entries
end

local function save_entries(file, entries)
  local temp = file .. ".tmp"
  local handle, err = io.open(temp, "w")
  if not handle then error("worktrunk: cannot write registry: " .. tostring(err), 0) end
  local ok, write_err = handle:write(rex.json.encode{ version = 1, entries = entries })
  local closed, close_err = handle:close()
  if not ok or not closed then
    os.remove(temp)
    error("worktrunk: cannot write registry: " .. tostring(write_err or close_err), 0)
  end
  local renamed, rename_err = os.rename(temp, file)
  if not renamed then os.remove(temp); error("worktrunk: " .. tostring(rename_err), 0) end
end

local function transaction(script, change)
  local scope = call("server.status").instance_id
  local directory = execute(script, "registry-lock", scope)
  local ok, id, created = pcall(function()
    local live = {}
    for _, session in ipairs(call("session.list").sessions or {}) do live[session.session_id] = session end
    local file = directory .. "/sessions.json"
    local entries = read_entries(file, live, script, scope)
    local result, is_new = change(entries, live)
    -- Save ownership before touching presentation. A failed rename can be
    -- repaired on the next operation without adopting a session by its label.
    save_entries(file, entries)
    for session_id, name in pairs(labels(entries, live)) do
      if live[session_id].label ~= name then
        call("session.attach", { session_id = session_id })
        call("session.set_label", { session_id = session_id, label = name })
      end
    end
    return result, is_new
  end)
  local unlocked, unlock_err = pcall(execute, script, "registry-unlock", scope)
  if not ok then error(id, 0) end
  if not unlocked then error(unlock_err, 0) end
  return id, created
end

function M.resolve(path, script, create)
  return transaction(script, function(entries, live)
    if entries[path] then return entries[path], false end
    if not create then return nil, false end
    -- The returned native ID is authoritative even when a readable name is
    -- temporarily shared during creation, or later changed by a person/agent.
    local id = create(bounded(path:match("[^/]+$") or "/"))
    entries[path], live[id] = id, { session_id = id, label = "" }
    return id, true
  end)
end

function M.forget(path, id, script)
  transaction(script, function(entries)
    if entries[path] == id then entries[path] = nil end
  end)
end

return M
