# Partial Success and Retries

These helpers are not transactional. Existing state is better evidence of what
completed than an exit code alone.

- `gwt-add` can leave a valid worktree even if later setup fails. Git's worktree
  registry and the checkout itself help establish what remains to do.
- Hook failures are warnings: `gwt-add` still exits zero. A hook may have partially
  completed side effects, so rerunning it is not necessarily harmless.
- `tms` can create a session but fail to create its second window. A retry sees
  the existing session and skips creation, potentially succeeding without fixing
  the missing window.

Recovery can build on successful steps rather than starting over. Distinguish
workspace availability from unfinished setup when reporting the result.
