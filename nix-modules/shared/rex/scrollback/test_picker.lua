local extract = require("extract")

local function equal(actual, expected)
  assert(#actual == #expected, table.concat(actual, "\n"))
  for i, value in ipairs(expected) do assert(actual[i] == value, actual[i] .. " ~= " .. value) end
end

equal(extract.urls("See (https://example.com/path?q=1&x=2)."), {
  "https://example.com/path?q=1&x=2",
})
equal(extract.urls([[www.example.com 10.0.0.1:8080/api git@github.com:owner/repo.git 'owner/repo']]), {
  "https://github.com/owner/repo",
  "https://github.com/owner/repo.git",
  "http://10.0.0.1:8080/api",
  "http://www.example.com",
})
equal(extract.urls("no links here"), {})
equal(extract.urls("https://one.example https://two.example https://one.example", 1), {
  "https://one.example",
})
equal(extract.urls("https://example.com/?x=1&y=2;whoami"), {
  "https://example.com/?x=1&y=2;whoami",
})
equal(extract.urls("ftp://example.com file:///tmp/demo ssh://git@host.example/owner/repo"), {
  "https://host.example/owner/repo", "file:///tmp/demo", "ftp://example.com",
})

local paths = {}
for i, item in ipairs(extract.file_candidates([[
README.md file://remote/tmp/no file:///tmp/reject%0Athis ~/project/notes.md
file://localhost/tmp/two%20words.txt?download=yes ./docs/../README.md
]], "/work", "/home/me")) do
  paths[i] = extract.absolute_path(item.path)
end
equal(paths, { "/work/README.md", "/tmp/two words.txt", "/home/me/project/notes.md", "/work/README.md" })
