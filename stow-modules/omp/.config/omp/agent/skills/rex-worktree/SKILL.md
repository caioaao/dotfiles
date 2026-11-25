---
name: rex-worktree
description: Create or open a Git worktree in Rex, check out a PR in Rex, launch Omp in the resulting session, or remove a managed worktree.
---

# Rex worktrees

Use Worktrunk for checkout changes and the configured Rex actions for session
ownership. Don't create a parallel session with `rex new` or drive `fzf`
with keystrokes. Use `rex skill show` for general Rex targeting and inspection.

## Open or create

Use the requested source checkout, or the current checkout if none was named.
Use the checkout itself for `-C`, not the repository's main checkout: `@`
means the source checkout's current HEAD. If the user asked for the focused
terminal specifically, inspect that terminal's cwd instead of assuming yours.

Run the matching command and capture its JSON stdout:

```bash
# Existing branch
wt -C "$source" switch --no-cd --format=json "$branch"

# New branch; substitute a different base only if requested
wt -C "$source" switch --create --base @ --no-cd --format=json "$branch"

# GitHub PR: target is pr:<number> or the PR URL
wt -C "$source" switch --no-cd --format=json "$target"
```

If the request doesn't distinguish an existing branch from a new one, resolve
the exact ref first. Don't treat a failed switch as evidence that the branch
doesn't exist. Preserve Worktrunk hooks and approval prompts; if a hook needs
approval, surface the prompt instead of bypassing it.

After a successful switch, read `.path` and confirm it names the checkout.
Use Worktrunk's output rather than constructing the path from the branch name.
If the checkout already exists and its path is known, go straight to:

```bash
rex do worktree_go --json "path=$path"
```

Use the returned `session_id` and canonical `path`. `created: false` means Rex
reused the session and kept its tabs. If Remote Control blocks selection,
report the failure and the checkout path; retry only the Rex action after
permission is fixed, not the checkout operation.

## Launch Omp

Only when requested, start an interactive Omp tab in the **returned session
ID**, not `$REX_SESSION` from the calling terminal:

```bash
rex run --json -s "$session_id" --label omp -c "$path" -- omp
```

If the user asked to hand off a task, append `"Task: $prompt"` as one
argument after `omp`. Don't pass a prompt for a request to open Omp idle.
Use the returned block ID to check that Omp started; tab creation alone
doesn't prove the process launched. Report the checkout path, whether the
Rex session was created or reused, and whether Omp started.

## Remove

Only on explicit request. Resolve the exact named, non-main checkout and
canonicalize both its path and the main checkout's path before deletion.
Tell the user that closing the managed session stops all its processes,
including Omp. Don't remove the checkout hosting this agent without an
explicit handoff.

```bash
wt -C "$main" remove --foreground "$path"
# Only after successful removal:
rex do worktree_close --json "path=$path" "main=$main"
```

Use no force flags. If Worktrunk refuses removal, leave Rex alone. If removal
succeeds but Rex close fails, report those outcomes separately.
