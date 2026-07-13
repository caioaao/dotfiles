---
name: context
description: Read and maintain the box-local agent context bundle at $XDG_STATE_HOME/agent-context. Use when starting work that may have prior context, or when recording durable cross-session findings, plans, or handoffs.
---

# Agent context bundle

Box-local, git-tracked context store shared across all repos/worktrees on this
machine. Bundle path: `$XDG_STATE_HOME/agent-context` (env var always set on
this box).

## Setup (self-healing)

If the bundle is missing, create it:

```bash
B="$XDG_STATE_HOME/agent-context"
[ -d "$B/.git" ] || { mkdir -p "$B" && git -C "$B" init -q && printf '# Agent context bundle\n\nBox-local cross-session context. See AGENTS.md for protocol.\n\n## Areas\n' > "$B/index.md" && git -C "$B" add -A && git -C "$B" commit -qm "Seed bundle"; }
```

## Read protocol

1. Open `$XDG_STATE_HOME/agent-context/index.md`. Navigate by names, links,
   and prose - progressive disclosure. Follow only links the task needs; never
   bulk-read the tree.
2. Judge relevance by cross-referencing your working tree with live git:
   `pwd`, `git remote -v`, `git branch --show-current` vs paths/branches named
   in docs. No lookup key exists - discovery is navigation.
3. Frontmatter `description`, when present, gates whether to open a doc.
   `type: Archive` = history, skip unless you need provenance.
4. Authority order: repo ADRs/specs > Linear > bundle. Bundle is supplementary
   state, never design authority.

## Write protocol

- One directory per project, one concern per doc.
- Name where a doc applies in prose (repo paths, globs, branches) - not a
  strict field. Frontmatter optional; nothing may depend on parsing it.
- Cross-link bundle-relative (`/project/context.md`). Update root `index.md`
  when adding or meaningfully changing docs.
- Supersede, don't rewrite: mark stale docs `type: Archive` + pointer to
  replacement.
- Commit after every meaningful update, staging only that update's files.
  Imperative, concise messages.
- Never cite bundle paths in commits, PRs, Linear, or durable docs.

## Helpers (optional convenience, not the mechanism)

- `scripts/ctx-new <project>` - scaffold `<project>/context.md` + index entry.
- `scripts/ctx-link-check` - report dead bundle-relative links + orphan docs.
- `scripts/ctx-commit [msg]` - stage bundle changes + commit.
