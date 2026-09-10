-- :Pi - start a pi session on the current file location
--
-- Usage:
--   :Pi                 prompt for the question, uses the current line
--   :'<,'>Pi            prompt for the question, uses the visual selection
--   :Pi <question>      skip the input dialog
--   :'<,'>Pi <question>
--
-- The session is opened in a new tmux window (in nvim's cwd) with the prompt:
--   On <file>:<line|start-end>: <question>

local function location(opts)
	local file = vim.fn.expand("%:.")
	if file == "" then
		return nil, "current buffer has no file name"
	end
	if opts.range == 0 then
		return file
	end
	if opts.line1 == opts.line2 then
		return string.format("%s:%d", file, opts.line1)
	end
	return string.format("%s:%d-%d", file, opts.line1, opts.line2)
end

local function start_session(prompt)
	if not vim.env.TMUX then
		vim.notify("Pi: not running inside tmux", vim.log.levels.ERROR)
		return
	end
	vim.system({
		"tmux",
		"new-window",
		"-n",
		"pi",
		"-c",
		vim.fn.getcwd(),
		"pi " .. vim.fn.shellescape(prompt),
	})
end

local function pi(opts)
	local loc, err = location(opts)
	if not loc then
		vim.notify("Pi: " .. err, vim.log.levels.ERROR)
		return
	end

	local function run(question)
		if not question or question == "" then
			return
		end
		start_session(string.format("On %s: %s", loc, question))
	end

	if opts.args ~= "" then
		run(opts.args)
	else
		vim.ui.input({ prompt = "Pi (" .. loc .. "): " }, run)
	end
end

vim.api.nvim_create_user_command("Pi", pi, {
	range = true,
	nargs = "*",
	desc = "Start a pi session on the current file location",
})
