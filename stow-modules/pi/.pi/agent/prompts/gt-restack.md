---
description: Resolve Graphite restack conflicts and drive the restack to a clean state
argument-hint: "[pause] [context: canonical side, plan path, PR summary...]"
---
Drive the in-progress `gt restack` to completion. Use `gt continue` / `gt abort`, never raw `git rebase --continue/--abort/--skip`.

Arguments are free-form context for deciding base vs incoming on each conflict. Read any referenced files. If ambiguous, stop and ask. `pause` means: resolve the current conflict only, don't stage or continue.

## Loop

1. `git status` + `gt log short` to map the stack and the unmerged files.
2. For each conflicted file:
   - Read the incoming commit (`git show <sha> -- <file>`) and the new base (`git show <onto-sha>:<file>`) before editing.
   - If the base was refactored, re-implement the incoming change against the new pattern. Do not paste the old code back.
   - Sorted-list collisions: keep both sides, preserve order.
   - Genuinely conflicting semantics on both sides: stop and ask.
   - Re-grep for conflict markers before staging.
3. `gt add` + `gt continue`. Repeat until clean.

## When clean

- Run the repo's compile/format/lint (in this repo: `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict` from `backend/`).
- Flag any `(needs restack)` siblings. Don't restack them without being asked.
- Don't force-push or `gt submit` unless `$@` says so.

## Output

- Branch + new parent.
- One bullet per conflict: `file - classification - resolution`.
- Verification exit codes.
- Any commits whose subject implies behavior change you re-implemented.

Arguments: $@
