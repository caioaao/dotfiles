---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

1. **See the current state** of the merge/rebase. Check git history and the conflicting files. Identify pre-existing staged and unstaged user work before editing; keep it separate from the operation's resolutions and preserve it throughout.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour. If intent cannot be reconciled safely, ask the user for the decision. Abort only with explicit user authorization, after ensuring pre-existing work will be preserved; the skill itself grants no abort authority.

4. Discover the project's **automated checks** and follow the host's verification and delegation rules about whether and when to run them. When authorized, run the relevant checks and fix anything the merge broke without overwriting unrelated work.

5. **Finish the authorized merge/rebase.** Stage only operation-owned resolutions, by explicit paths or hunks; leave unrelated staged and unstaged work untouched. If a commit or rebase continuation would include unrelated staged changes, pause for the user's decision rather than committing or unstaging their work. Commit or continue only within the user's authorization. If rebasing, resolve each remaining conflict using the same process until all commits are rebased.
