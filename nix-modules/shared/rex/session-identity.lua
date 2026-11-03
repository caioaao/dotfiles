-- Run only on an isolated Rex server:
-- rex -S unix:///tmp/isolated.sock do ./session-identity.lua \
--   plugin=/nix/store/.../share/rex/rex-worktrunk picker=/nix/store/.../bin/rex-worktrunk-picker root=/tmp/fixture
-- root must contain a/api, b/api, main, and alias -> a/api. No GUI required.
local plugin = dofile(rex.args.plugin .. "/init.lua")
plugin.setup{ script = rex.args.picker }
local normalized = rex.exec{ rex.args.picker, "normalize", rex.args.root }
assert(normalized and normalized.ok)
local root = normalized.stdout:gsub("\n$", "")
local function call(method, args)
  local result, err = rex.call(method, args)
  assert(result, tostring(err))
  return result
end
local function inventory()
  local result = {}
  for _, s in ipairs(call("session.list").sessions) do result[s.label] = s.session_id end
  return result
end
assert(next(inventory()) == nil, "test requires an empty isolated server")
local native = call("session.create", { label = "api" }).session_id
local function visit(path)
  local ok, err = pcall(plugin.go, { origin = "cli" }, path)
  -- With no GUI the real session is created but presentation fails explicitly.
  assert(not ok and tostring(err):find("is ready, but the app would not show it", 1, true), tostring(err))
end
visit(root .. "/a/api")
visit(root .. "/b/api")
local before = inventory()
local a, b = before["wt:" .. root .. "/a/api"], before["wt:" .. root .. "/b/api"]
assert(a and b and a ~= b and a ~= native and b ~= native)
visit(root .. "/alias/")
visit(root .. "/a/./api/")
local after = inventory()
assert(after["wt:" .. root .. "/a/api"] == a)
local count = 0
for _ in pairs(after) do count = count + 1 end
assert(count == 3, "normalization created a duplicate session")
local removed = rex.exec{ "rmdir", root .. "/a/api" }
assert(removed and removed.ok)
assert(plugin.close({}, root .. "/a/api/", root .. "/main").closed)
after = inventory()
assert(after["api"] == native and after["wt:" .. root .. "/b/api"] == b)
assert(after["wt:" .. root .. "/a/api"] == nil)
assert(not plugin.close({}, root .. "/missing", root .. "/main").closed)
-- With no viewing app, fallback must fail rather than destroy the active session.
local ok = pcall(plugin.close, {session_id = b, origin = "cli"}, root .. "/b/api", root .. "/main")
assert(not ok and inventory()["wt:" .. root .. "/b/api"] == b)
assert(inventory()["wt:" .. root .. "/main"], "main fallback session not created")
return { same_basename = true, native_preserved = true, normalized_reuse = true,
  close_after_removal = true, missing_session = true, failed_fallback_preserves_session = true }
