-- :AI - start an omp session on the current file location
--
-- Usage:
--   :AI                 prompt for the question, uses the current line
--   :'<,'>AI            prompt for the question, uses the visual selection
--   :AI <question>      skip the input dialog
--   :'<,'>AI <question>
--
-- Inside Rex, opens a window on $REX_SERVER in the session containing $REX_BLOCK.
-- Outside Rex, uses tmux.
-- It uses nvim's cwd with the prompt:
--   On <file>:<line|start-end>: <question>
-- The omp executable is resolved through nvim's PATH.

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
	local server = vim.env.REX_SERVER
	if server and server ~= "" then
		local block = vim.env.REX_BLOCK
		if not block or block == "" then
			vim.notify("AI: REX_BLOCK is missing; cannot target the Rex session", vim.log.levels.ERROR)
			return
		end
		vim.system({
			"rex",
			"--server",
			server,
			"--autostart=false",
			"run",
			"--session",
			block,
			"--label",
			"omp",
			"-c",
			vim.fn.getcwd(),
			"--",
			vim.fn.exepath("omp"),
			prompt,
		}, {}, vim.schedule_wrap(function(result)
			if result.code ~= 0 then
				vim.notify("AI: rex run failed: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
			end
		end))
		return
	end
	if not vim.env.TMUX then
		vim.notify("AI: not running inside Rex or tmux", vim.log.levels.ERROR)
		return
	end
	vim.system({
		"tmux",
		"new-window",
		"-n",
		"omp",
		"-c",
		vim.fn.getcwd(),
		"omp " .. vim.fn.shellescape(prompt),
	})
end

local function ai(opts)
	local loc, err = location(opts)
	if not loc then
		vim.notify("AI: " .. err, vim.log.levels.ERROR)
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
		vim.ui.input({ prompt = "AI (" .. loc .. "): " }, run)
	end
end

vim.api.nvim_create_user_command("AI", ai, {
	range = true,
	nargs = "*",
	desc = "Start an omp session on the current file location",
})
