---
name: claude-handoff
description: Hand the current conversation off to a fresh background agent that picks up the work immediately.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff summary of the current conversation so a fresh Claude Code agent can continue the work. Save the redacted summary to a private file in `${TMPDIR:-/tmp}` using the host's file-writing tool, then launch Claude from the current working directory. Create the file with mode `0600` (for example, reserve its path with `umask 077; mktemp "${TMPDIR:-/tmp}/claude-handoff.XXXXXX"`). Keep summary content out of shell source, including interpolated commands and unquoted heredocs.

Pass the file's contents as one quoted argument after `--`:

```bash
claude --bg --name 'Fix login bug' -- "$(cat -- '/absolute/path/to/summary-file')"
```

Use the actual reserved path and a descriptive name, shell-quoting each literal argument: enclose it in single quotes and replace any embedded `'` with `'\''`. The quoted command substitution passes summary text as data; backticks, dollar signs, quotes, newlines, and leading dashes in it are not executed or parsed as options. It returns immediately; the user manages the background agent with `claude agents`. Remove the temporary summary file after a successful launch; retain it and report its path if launch fails.

Always pass `-n`/`--name` with a descriptive name (e.g. `--name "Fix login bug"`); it sets the display name shown in the job list, session picker, and terminal title.

Include a "suggested skills" section in the summary, naming which skills the next Claude Code agent should load through its available skill mechanism.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information, since the summary becomes the agent's prompt.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the summary accordingly.
