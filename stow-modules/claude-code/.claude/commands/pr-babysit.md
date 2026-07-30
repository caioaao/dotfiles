---
description: Watch the current branch's PR until merged - fix CI, address reviews, handle conflicts
argument-hint: "[PR number/URL] [extra instructions]"
---
Babysit the PR until it is merged/closed or blocked on a human. Green + mergeable + review-clean is a milestone, not a stop condition - keep watching for late reviews unless I say otherwise.

Target: `gh pr checks` (and other `gh pr` subcommands) resolve the PR from the current branch. If `$1` is a PR number or URL, pass it explicitly instead. Remaining args are extra instructions.

## Loop

1. **State check first.** `gh pr view --json state,mergeable,mergeStateStatus,reviewDecision`. Merged or closed -> report and stop. Never loop on an already-merged PR.
2. **Wait on CI.** `gh pr checks --watch --fail-fast`. If checks are still queued, keep waiting - don't declare anything from a partial run.
3. **Triage, in priority order:**
   1. **Failing checks.** `gh run view <run-id> --log-failed`. Classify:
      - *Branch-related* (log points at changed code): minimal fix, verify locally when the repo has a cheap check (lint/typecheck/tests for touched area), commit, push. New commits, no amends, no `--no-verify`.
      - *Flaky/infra* (timeouts, runner errors, unrelated code): rerun via `gh run rerun <run-id> --failed`. Budget: 3 reruns per check. Never patch code to appease a flake.
      - *Not fixable from code* (secrets, permissions, failures that also exist on the base branch): report and skip.
   2. **Review threads.** Use the `pr-unresolved-threads` skill. For each unresolved thread:
      - Actionable and unambiguous -> fix, commit, push. Reference the thread in the commit message body.
      - Question -> draft an answer for me; don't post replies without confirmation.
      - Subjective, architectural, or ambiguous -> surface to me, don't guess.
      - Never resolve threads - that's the reviewer's call.
   3. **Merge conflicts** (`mergeable: CONFLICTING`): rebase on the base branch, `git push --force-with-lease`. In Graphite repos use `gt restack`/`gt submit` instead of raw rebase. Auto-resolve only lockfiles and generated files; abort and escalate on source-logic conflicts. Never bare `--force`.
4. Report status transitions only (check went red -> fixed -> green, new review, etc). No noisy heartbeats.
5. Nothing changed this iteration (green, no new threads) -> `sleep 60` before re-polling. Go to 1.

## Circuit breakers

- Same check fails twice with the same error after a fix -> stop fixing, summarize the failure (check name, first ~25 log lines, hypothesis).
- Max 3 fix attempts per check, max 3 flaky reruns per check.
- Anything requiring human judgment (approval, subjective review, non-trivial conflict, secrets) -> report and pause on that item; keep babysitting the rest.

## Hard rules

- Never merge the PR. Report when it's merge-ready; merging is my call.
- Head branch only. Stop if there are unrelated uncommitted changes in the worktree.
- No force-push to the base branch, ever.

## Final report

- PR state, head SHA, checks x/y.
- Commits pushed (one line each) and reruns used.
- Open items needing me: threads, approvals, blockers.

Arguments: $ARGUMENTS
