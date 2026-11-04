-- Run ONLY on an empty, isolated Rex server without a viewing app. Start both
-- server and this CLI with the SAME private XDG_STATE_HOME, never personal state.
-- XDG_STATE_HOME=/tmp/fixture/state rex --autostart=false -S unix:///tmp/isolated.sock do ./test/session-identity.lua \
--   plugin=/nix/store/.../share/rex/worktrees \
--   picker=/nix/store/.../bin/rex-worktree-picker root=/tmp/fixture
-- Prepare root/a/api, root/b/api, root/main, root/legacy, and root/alias -> a/api.
-- The fixture root must be disposable: this script removes a/api and creates
-- long, Unicode, and control-containing directory names. Its canonical legacy
-- label ("wt:" .. root .. "/legacy") must fit the server's 128-character limit.
local function call(method, args)
  local result, err = rex.call(method, args)
  assert(result, method .. ": " .. tostring(err))
  return result
end
local function exec(args)
  local result = rex.exec(args)
  assert(result and result.ok, "fixture command failed: " .. tostring(args[1]))
  return result.stdout or ""
end
local function inventory()
  local result = { by_id = {}, by_label = {}, count = 0 }
  for _, session in ipairs(call("session.list").sessions) do
    assert(not result.by_id[session.session_id], "duplicate session ID in inventory")
    result.by_id[session.session_id] = session.label
    result.by_label[session.label] = result.by_label[session.label] or {}
    table.insert(result.by_label[session.label], session.session_id)
    result.count = result.count + 1
  end
  return result
end
local function only_label(label)
  local matches = inventory().by_label[label] or {}
  assert(#matches == 1, "expected exactly one session labelled " .. label)
  return matches[1]
end
local function expect_label(id, label)
  assert(inventory().by_id[id] == label, "unexpected label for session " .. id .. "; expected " .. label)
end
local function expect_count(expected)
  assert(inventory().count == expected, "unexpected session count; expected " .. expected)
end
local function expect_unchanged(before)
  local after = inventory()
  assert(after.count == before.count, "session count changed unexpectedly")
  for id, label in pairs(before.by_id) do
    assert(after.by_id[id] == label, "session changed unexpectedly: " .. id)
  end
end
assert(inventory().count == 0, "test requires an empty isolated server")
local state_home = exec{ "printenv", "XDG_STATE_HOME" }:gsub("\n$", "")
assert(state_home ~= "", "start the isolated server with a private XDG_STATE_HOME")
local root = exec{ rex.args.picker, "normalize", rex.args.root }:gsub("\n$", "")
local root_name = assert(root:match("([^/]+)$"), "fixture root cannot be /")
for _, relative in ipairs{ "a/api", "b/api", "main", "legacy", "alias" } do
  exec{ "test", "-d", root .. "/" .. relative }
end
assert(exec{ rex.args.picker, "normalize", root .. "/alias" }:gsub("\n$", "") == root .. "/a/api",
  "fixture alias must resolve to a/api")
local instance_id = assert(call("server.status").instance_id, "server lacks instance_id")
exec{ "test", "!", "-e", state_home .. "/rex/worktrunk/" .. instance_id .. "/sessions.json" }

-- Seed the legacy reserved label BEFORE the first registry operation. The native
-- label is deliberately not api, so the first checkout can use its basename.
local native = call("session.create", { label = "legacy" }).session_id
local legacy = call("session.create", { label = "wt:" .. root .. "/legacy" }).session_id
local function load_plugin()
  local module = dofile(rex.args.plugin .. "/init.lua")
  module.setup{ script = rex.args.picker }
  return module
end
local plugin = load_plugin()
local function visit(path)
  local ok, err = pcall(plugin.go, { origin = "cli" }, path)
  -- Real callbacks create/reuse the session; only presentation fails without an app.
  assert(not ok and tostring(err):find("is ready, but the app would not show it", 1, true), tostring(err))
end
visit(root .. "/a/api")
local a = only_label("api")
assert(a ~= native and a ~= legacy)
expect_count(3)
visit(root .. "/b/api")
local b = only_label("b/api")
assert(a ~= b and b ~= native and b ~= legacy)
expect_label(a, "a/api")
expect_count(4)

-- Exact legacy migration keeps the old ID, while the native same-basename
-- session is neither renamed nor adopted. Its label forces a longer suffix.
visit(root .. "/legacy")
expect_label(legacy, root_name .. "/legacy")
expect_label(native, "legacy")
expect_count(4)
visit(root .. "/alias/")
visit(root .. "/a/./api/")
expect_label(a, "a/api")
expect_count(4)

-- Change the managed label before reloading: a label-based lookup, including a
-- basename fallback, cannot pass this fresh-module reuse check.
call("session.attach", { session_id = a })
call("session.set_label", { session_id = a, label = "manually-renamed-checkout" })
expect_label(a, "manually-renamed-checkout")
plugin = load_plugin()
visit(root .. "/alias/")
expect_label(a, "a/api")
expect_label(b, "b/api")
expect_label(native, "legacy")
expect_count(4)

-- Removal normalizes a now-missing directory, destroys exactly its registered
-- ID, and lets the surviving checkout return to its shortest label.
exec{ "rmdir", root .. "/a/api" }
assert(plugin.close({}, root .. "/a/api/", root .. "/main").closed)
assert(inventory().by_id[a] == nil, "removed checkout's session survived")
expect_label(b, "api")
expect_label(legacy, root_name .. "/legacy")
expect_label(native, "legacy")
expect_count(3)
local before_missing = inventory()
assert(not plugin.close({}, root .. "/missing/legacy", root .. "/main").closed)
expect_unchanged(before_missing)

-- Concurrent operations must fail before changing sessions, rather than create
-- duplicates or lose another transaction's association.
local before_lock = inventory()
exec{ rex.args.picker, "registry-lock", instance_id }
local lock_ok, lock_err = pcall(plugin.go, { origin = "cli" }, root .. "/b/api")
exec{ rex.args.picker, "registry-unlock", instance_id }
assert(not lock_ok and tostring(lock_err):find("registry is busy", 1, true), tostring(lock_err))
expect_unchanged(before_lock)

-- A session closed outside the plugin leaves stale state. A new native session
-- with that label must not be mistaken for the former managed session.
local stale_path = root .. "/stale-checkout"
exec{ "mkdir", "-p", stale_path }
visit(stale_path)
local stale_id = only_label("stale-checkout")
call("session.attach", { session_id = stale_id })
call("session.destroy", { session_id = stale_id })
local stale_native = call("session.create", { label = "stale-checkout" }).session_id
local before_stale = inventory()
visit(stale_path)
local replacement = only_label(root_name .. "/stale-checkout")
assert(replacement ~= stale_id and replacement ~= stale_native)
expect_label(stale_native, "stale-checkout")
expect_count(before_stale.count + 1)

-- Distinct overlong basenames sharing their readable prefix must have distinct,
-- bounded labels and identities. Reopening checks that the path is not truncated
-- along with its display label.
local long_one = root .. "/" .. string.rep("x", 140)
local long_two = root .. "/" .. string.rep("x", 139) .. "y"
local function create_and_visit(path)
  exec{ "mkdir", "-p", path }
  local before = inventory()
  visit(path)
  local after = inventory()
  assert(after.count == before.count + 1, "new checkout did not create exactly one session")
  local created
  for id in pairs(after.by_id) do
    if not before.by_id[id] then
      assert(not created, "new checkout created multiple sessions")
      created = id
    end
  end
  return assert(created)
end
local long_a = create_and_visit(long_one)
local long_b = create_and_visit(long_two)
local long_labels = inventory().by_id
assert(long_labels[long_a] ~= long_labels[long_b], "bounded labels collided")
for _, id in ipairs{ long_a, long_b } do
  local label = long_labels[id]
  assert(#label <= 128 and label:find("xxx", 1, true), "long basename lost readable bounded label")
  assert(not label:find("[%z\1-\31\127]"), "long label contains controls")
end
local before_revisit = inventory()
visit(long_one .. "/")
visit(long_two)
expect_unchanged(before_revisit)

-- Unicode labels below and exactly at 128 characters stay intact even when
-- their encodings exceed 128 bytes. The overlong basename has 130 characters
-- but only 250 bytes, within the filesystem's 255-byte component limit.
local unicode_name = string.rep("界", 70)
local unicode_id = create_and_visit(root .. "/" .. unicode_name)
expect_label(unicode_id, unicode_name)
local unicode_boundary_name = string.rep("é", 127) .. "x"
local unicode_boundary_id = create_and_visit(root .. "/" .. unicode_boundary_name)
expect_label(unicode_boundary_id, unicode_boundary_name)
local unicode_long_path = root .. "/" .. string.rep("é", 120) .. string.rep("x", 10)
local unicode_long_id = create_and_visit(unicode_long_path)
local unicode_long_label = inventory().by_id[unicode_long_id]
local counted = unicode_long_label:gsub("é", "e")
assert(not counted:find("[\128-\255]"), "bounded Unicode label contains a partial UTF-8 character")
assert(#counted <= 128 and unicode_long_label:find("é", 1, true), "Unicode label is not readable and bounded")
before_revisit = inventory()
visit(unicode_long_path)
expect_unchanged(before_revisit)

local control_id = create_and_visit(root .. "/control\tcheckout\nname")
local control_label = inventory().by_id[control_id]
assert(not control_label:find("[%z\1-\31\127]"), "display label contains controls")
assert(control_label:find("control", 1, true), "sanitized label lost readable basename")

-- The caller's active session must survive if moving to main cannot be shown.
-- main is really created, but the lack of a viewing app prevents destruction.
local before_fallback = inventory()
local ok, err = pcall(plugin.close, { session_id = b, origin = "cli" }, root .. "/b/api", root .. "/main")
assert(not ok and tostring(err):find("is ready, but the app would not show it", 1, true), tostring(err))
expect_label(b, "api")
local main = only_label("main")
assert(not before_fallback.by_id[main], "main fallback reused an unrelated session")
expect_count(before_fallback.count + 1)
for id, label in pairs(before_fallback.by_id) do expect_label(id, label) end
expect_label(native, "legacy")

-- Lost state must not turn readable-name equality into ownership. The existing
-- short-label sessions remain running, and a new managed session is separate.
exec{ "rm", state_home .. "/rex/worktrunk/" .. instance_id .. "/sessions.json" }
local before_loss = inventory()
visit(root .. "/b/api")
expect_count(before_loss.count + 1)
expect_label(b, "api")
local recovered = only_label("b/api")
assert(recovered ~= b)
assert(plugin.close({}, root .. "/b/api", root .. "/main").session_id == recovered)
for id, label in pairs(before_loss.by_id) do expect_label(id, label) end
return { basename_label = true, same_basename = true, native_preserved = true,
  legacy_migration = true, normalized_reuse = true, reloaded_registry = true,
  manual_rename_reuse = true, close_after_removal = true, survivor_shortened = true,
  missing_session = true, bounded_labels = true, unicode_bounds = true,
  sanitized_controls = true, failed_fallback_preserves_session = true,
  lock_refusal = true, stale_id_recovery = true, registry_loss_isolation = true }
