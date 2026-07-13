---
description: Load context bundle and identify next task
argument-hint: "[project-name]"
---
Identify the next task from the agent context bundle.

1. Load the `context` skill and follow its read protocol (index.md navigation, cross-reference working tree vs live git). If `${1:-}` names a project, jump straight to it.
2. Scan the loaded docs for pending/completed checklists, plan phases, and blockers. Cross-check Linear when docs cite tickets.
3. Answer: what is the next task, why is it next (dependencies, blockers), and what does done look like. Ask before starting execution.
