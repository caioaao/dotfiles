---
name: setup-worktree
description: Set up a Git worktree and tmux session using gwt-add and tms. Use when asked to create an isolated checkout or a tmux workspace for parallel branch work.
---

# Set Up a Worktree

Prepare a checkout for the intended branch and a tmux workspace using `gwt-add`
and `tms`. Use the request and repository state to choose the starting point,
reuse existing resources where appropriate, and decide what needs verification.

Preserve unrelated work. Prefer a detached session unless the user wants to
switch to it. Creating a workspace does not move the current Pi session.

## Tool notes

Load these as useful, not as a required sequence. Links are relative to this skill.

- [Worktrees](references/worktree-cases.md): branch defaults, existing checkouts,
  and post-create hooks.
- [Tmux](references/tmux-session.md): invocation, path conventions, and sessions.
- [Recovery](references/recovery.md): partial success and retry limitations.

Finish with the branch, worktree path, session name, and anything left unresolved.
