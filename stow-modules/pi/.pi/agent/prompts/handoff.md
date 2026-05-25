---
description: Write a self-contained follow-up prompt for the next session
argument-hint: "<scope-or-ticket> [output-path] [extra context...]"
---
Author a self-contained follow-up prompt for a fresh session. The next session will consume this with `/drive-slice` (or equivalent) and has **no memory of this conversation**.

Scope: `$1`
Output: `${2:-.local/$1-followup.md}` (gitignored scratch — never committed)

The follow-up must be reconstructable from disk alone. Include:

1. **Branch targeting.** Explicit instructions:
   - Which branch to work on (never create a new one unless told)
   - Which commit to amend (e.g. `gt modify <sha>`, `gt absorb`, `git commit --amend`) or whether to add new commits
   - Whether to restack / submit at the end
2. **Context anchors.** Paths and SHAs only — no narrative recap:
   - Spec / ADR / rule paths in the repo's doc tree
   - Plan / structure / slice paths under `.local/`
   - Relevant commits (`git show <sha>`)
   - Sibling patterns to mirror (`path:line`)
3. **Applicable rules.** Research the repo for rules touched by this scope; cite by filename. Quote the load-bearing lines if they're short.
4. **Acceptance criteria.** What "done" means, in checkboxes the next agent can tick.
5. **Verification steps.** Exact commands the repo uses (tests, typecheck, lint, format). Include expected exit codes / output shape.
6. **Privacy invariants.** Re-assert: no `.local/` paths in code/commits/PR bodies; imperative-mood commits; describe the change, not the workflow.

Research the codebase first to fill the anchors and rules. Don't write the file until you've gathered enough that a fresh session won't need to re-discover anything.

When done: write the file, then emit a one-line summary of what's in it.

Arguments: $@
