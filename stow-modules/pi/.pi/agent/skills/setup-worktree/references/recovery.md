# Partial Success and Retries

Worktree creation and tmux setup are separate operations. Existing state is
better evidence of what completed than an exit code alone.

- A valid worktree may remain even if later setup fails. Git's worktree registry
  and the checkout itself help establish what remains to do.
- `tms` can create a session but fail to create its second window. A retry sees
  the existing session and skips creation, potentially succeeding without fixing
  the missing window.

Recovery can build on successful steps rather than starting over. Distinguish
workspace availability from unfinished setup when reporting the result.
