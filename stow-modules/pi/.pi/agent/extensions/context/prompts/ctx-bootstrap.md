---
description: Bootstrap context bundle project for current work
argument-hint: "[project-name]"
---
Bootstrap a project in the agent context bundle.

1. Load the `context` skill. If the bundle is missing, run its self-healing setup.
2. Determine project name: use `${1:-}` if given, otherwise derive from working tree (`pwd`, `git remote -v`, current branch). Check the bundle `index.md` first - if a project already exists for this work, stop and tell me instead of duplicating.
3. Scaffold via `scripts/ctx-new <project>`.
4. Interview me (questionnaire) for: intent/goal, scope, and where it applies (repo paths, branches, tickets).
5. Fill in `<project>/context.md` from the answers, fix the index entry description, and commit via `scripts/ctx-commit`.
