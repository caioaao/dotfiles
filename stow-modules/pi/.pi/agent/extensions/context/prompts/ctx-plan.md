---
description: Write implementation plan into context bundle
argument-hint: "<topic>"
---
Write an implementation plan for: $@

1. Load the `context` skill and the `fresh-eyes` skill.
2. Load existing project context first (read protocol). Recon the codebase as needed - use subagents for heavy recon.
3. Write the plan doc into the bundle project directory (`<project>/plan-<slug>.md` or similar), not inline in chat. Structure as slices/phases with handoff checklists.
4. Fresh-eyes review before presenting.
5. Update index/context.md links and commit the bundle.
6. In chat, output only: pointer to the doc + completed/pending checklist.
