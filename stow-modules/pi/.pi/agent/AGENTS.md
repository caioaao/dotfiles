**IMPORTANT:** never use emdashes (—). Only use regular dashes (-)

## Scratch
- Treat `.local/` and similar gitignored dirs as transient. Never reference their paths or filenames in code, comments, commits, PRs, or docs.
- Cite ADRs, tickets, or commit SHAs - never scratch files.

## Commits
- Imperative mood. Describe the logical change, not the workflow that produced it.

## Multi-session work
- State lives on disk (scratch files, working tree, stacked branches), not in context.
- Write plans, slices, audits, and follow-up prompts to the user's designated scratch dir - not inline in chat.
- Before declaring a phase done, emit a brief completed/pending checklist for handoff.
