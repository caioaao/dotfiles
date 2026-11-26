local M = {}

function M.urls(text, limit)
  local matches = {}
  local function add(pos, url)
    matches[#matches + 1] = { pos = pos, url = url }
  end

  local middle = "[-A-Za-z0-9+&@#/%%?=~_|!:,.;]"
  local last = "[-A-Za-z0-9+&@#/%%=~_|]"
  for _, scheme in ipairs({ "https?", "ftp", "file" }) do
    for pos, url in text:gmatch("()(" .. scheme .. ":///?" .. middle .. "*" .. last .. ")") do
      add(pos, url)
    end
  end

  local function add_http(pos, after)
    local _, path_end = text:find("^/[^%s'\"`<>]*", after)
    add(pos, "http://" .. text:sub(pos, path_end or after - 1))
  end
  for pos, label, after in text:gmatch("()%f[%w_]www%.([A-Za-z][A-Za-z0-9%-]+)%.[A-Za-z][A-Za-z]+()") do
    if label:sub(-1) ~= "-" and not label:find("--", 1, true) then
      add_http(pos, after)
    end
  end
  local octet = "%d%d?%d?"
  local ipv4 = table.concat({ octet, octet, octet, octet }, "%.")
  for pos, after in text:gmatch("()%f[%w_]" .. ipv4 .. "()") do
    local _, port_end = text:find("^:%d%d?%d?%d?%d?", after)
    add_http(pos, port_end and port_end + 1 or after)
  end

  for pos, host, repo in text:gmatch("()git@([^%s:'\"`<>/]+)[:/]([^%s'\"`<>]+)") do
    if pos > 6 and text:sub(pos - 6, pos - 1) == "ssh://" then pos = pos - 6 end
    add(pos, "https://" .. host .. "/" .. repo)
  end
  for pos, repo in text:gmatch("()['\"]([_A-Za-z0-9%-]+/[_.A-Za-z0-9%-]+)['\"]") do
    add(pos, "https://github.com/" .. repo)
  end

  table.sort(matches, function(a, b)
    if a.pos == b.pos then return a.url > b.url end
    return a.pos > b.pos
  end)
  local items, seen = {}, {}
  for _, match in ipairs(matches) do
    if not seen[match.url] then
      seen[match.url] = true
      items[#items + 1] = match.url
      if #items == limit then break end
    end
  end
  return items
end

function M.absolute_path(path)
  -- Lexical normalization, not realpath: symlinks are not followed here.
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      parts[#parts] = nil
    elseif part ~= "." then
      parts[#parts + 1] = part
    end
  end
  local root = path:sub(1, 2) == "//" and path:sub(3, 3) ~= "/" and "//" or "/"
  return root .. table.concat(parts, "/")
end

function M.file_candidates(text, cwd, home)
  local by_path = {}
  for pos, token in text:gmatch("()([^%s`'\"<>()%[%]{}]+)") do
    local path = token:gsub("[.,;:]+$", "")
    if path:sub(1, 7) == "file://" then
      local authority, uri_path = path:match("^file://([^/?#]*)([^?#]*)")
      path = nil
      if authority == "" or authority == "localhost" then
        path = uri_path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
      end
    elseif path:find(":", 1, true) or not path:find("[/%.]") then
      path = nil
    end
    if path and path ~= "" and not path:find("%c") then
      if home and path:sub(1, 2) == "~/" then path = home .. path:sub(2) end
      local absolute = path:sub(1, 1) == "/" and path or cwd .. "/" .. path
      by_path[absolute] = { path = absolute, title = path, pos = pos }
    end
  end
  local items = {}
  for _, item in pairs(by_path) do items[#items + 1] = item end
  table.sort(items, function(a, b) return a.pos > b.pos end)
  return items
end

return M
