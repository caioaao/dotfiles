# Git Worktrees

`git worktree` supports existing branches, new branches from a chosen starting
point, and detached checkouts. The request and repository conventions determine
which fits; Git's built-in help covers the available options.

- The destination is independent of the branch name. A location compatible with
  `tms`'s projects directory makes session setup straightforward.
- Worktrees have separate working directories and indexes, but share repository
  data and most refs. Uncommitted changes stay in their original checkout.
- Git normally rejects checking out a branch already used by another worktree.
  `git worktree list` helps identify reusable checkouts; repository and branch
  identity matter more than the directory name.
- An existing local branch and a new branch based on a remote-tracking ref are
  different starting points. Neither necessarily matches the current HEAD.
