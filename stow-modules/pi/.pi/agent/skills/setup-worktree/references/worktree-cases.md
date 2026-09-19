# Worktree Behavior

`gwt-add "$branch"` creates a worktree at the current checkout root's parent plus
the branch name. Slashes in the name produce nested directories.

- An existing local branch is used as-is; otherwise a new branch starts at the
  current HEAD. Uncommitted changes remain in the source checkout.
- The helper takes no base-ref argument and does not explicitly select a
  remote-tracking branch. A different starting point needs separate handling.
- An existing destination is rejected. Git also normally rejects checking out
  a branch already used by another worktree. Existing worktrees may be reusable;
  their repository and branch identity matter more than their directory name.
- When configured, `GWT_POST_CREATE_HOOK` runs inside the new worktree with
  `GWT_WORKTREE_DIR`, `GWT_BRANCH_NAME`, and `GWT_ROOT_DIR` exported. Hook output
  can follow the helper's path message, so the last output line is not a reliable
  way to discover the worktree.
