---
description: Scrub transient `.local/` references from code, comments, commits, and PR bodies
---
Drop all mentions of files under `.local/` — they are gitignored scratch and won't survive merge.

Steps:
1. Search the working tree (staged + unstaged + committed-on-this-branch) for `.local/` references:
   ```bash
   git diff $(git merge-base HEAD @{upstream})..HEAD | grep -nE '\.local/'
   git log $(git merge-base HEAD @{upstream})..HEAD --format='%H %s%n%b' | grep -nE '\.local/'
   ```
   Also scan code comments, docstrings, test descriptions, and migration comments.
2. For each occurrence, rewrite:
   - **Code comments / docstrings** → drop the reference. If the comment loses meaning, drop the comment too; the code should speak for itself.
   - **Commit messages** → `gt modify <sha>` (or `git commit --amend` / `git rebase -i`) to rewrite. Use imperative mood describing the logical change.
   - **PR body** → edit via `gh pr edit --body-file -`.
3. Also drop **prose references** that imply scratch context: "per refactoring plan 3", "see slice 1", "per the design doc", "§1.2". Commit messages describe **what changed**, not **why we got here**.
4. After scrubbing, re-run the search. Confirm zero matches.
5. If the branch is stacked: `gt restack` to propagate amends.

Do not delete the `.local/` files themselves — they're useful scratch. Only remove **references** to them from committed artifacts.
