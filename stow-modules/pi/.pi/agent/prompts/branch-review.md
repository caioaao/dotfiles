---
description: Pre-flight branch review - commit-by-commit audit before opening a PR
argument-hint: "[base-branch] [extra focus areas...]"
---
Review the current branch commit-by-commit. **Audit only - no fixes yet.**

Base: `${1:-main}` (or whatever `gt parent` reports for stacked branches in repos managed with Graphite).

Steps:
1. List the commits in scope:
   ```bash
   git log --oneline ${1:-main}..HEAD
   ```
2. For each commit, in order:
   - Read the diff (`git show <sha>`).
   - Check: scope creep, missing tests, regressions, hallucinated conventions, BC layers that weren't asked for, log spam, debug code.
   - Cross-reference relevant rules, ADRs, and plan files in the repo.
3. Delegate codebase context-gathering when useful, so the orchestrator stays lean.
4. For each finding: cite the commit SHA + file:line, state the issue, propose the fix in one line.
5. End with a remediation hint: which findings can be `gt absorb`'d vs need a new commit.

Do not write to disk unless asked. The report goes in the final assistant message - it's the handoff artifact.

Focus areas (from `$@` beyond `$1`): $@
