---
description: Load relevant context bundle docs for current work
argument-hint: "[project-name]"
---
Load context from the agent context bundle.

1. Load the `context` skill and follow its read protocol: navigate `index.md`, cross-reference my working tree against live git, progressive disclosure - open only what the task needs.
2. If `${1:-}` names a project, jump straight to that project's directory in the bundle.
3. Finish with a brief summary: what was loaded, current state, open questions.
