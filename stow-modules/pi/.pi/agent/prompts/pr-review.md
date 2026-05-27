---
description: Address PR review comments - validate, fix, absorb into existing commits
argument-hint: "<PR-URL-or-number> [validate|absorb|push|extra notes...]"
---
Address the review comments on PR `$1`.

Steps:
1. **Fetch unresolved threads** using the `pr-unresolved-threads` skill with `$1`.
2. **Classify each thread:** *agree* / *disagree* / *needs-discussion*.
3. **Read surrounding code** (file + ±20 lines) before deciding - comments without context are easy to misjudge.
4. **For "agree":** implement the fix. Keep it scoped to the thread.
5. **For "disagree":** draft a reply explaining the reasoning. Do not implement.
6. **Absorb, do not pile commits.** Use `gt absorb -d` to fold fixes into the existing commit they amend. Only create a new commit if the fix is genuinely additive.
7. **Do NOT resolve threads.** That's the user's call.
8. Run repo verification (format/typecheck/lint/test) before declaring done. Paste exit codes.

Modifiers (parsed from `$@`):
- `validate` → for each thread, output the classification + reasoning **before** touching code. Wait for confirmation.
- `absorb` → force `gt absorb` even for borderline cases. Default already prefers absorb.
- `push` → after fixes, `gt submit --no-interactive` (or `git push --force-with-lease`).

Arguments: $@
