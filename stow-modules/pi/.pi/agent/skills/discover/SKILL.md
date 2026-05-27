---
name: discover
description: Discovery phase - surface codebase facts about a feature into a scratch findings artifact, before planning or coding. Use when bootstrapping work on a new feature, ticket, or change scope.
disable-model-invocation: true
---

# Discover

Produce a discovery artifact for a feature or ticket. **No code yet, no plan yet.** The goal is to map the relevant surface of the codebase so a fresh session can plan against facts, not guesses.

## Input

- A topic slug (used as the output filename)
- Optionally: an anchor - a spec path, ticket description, anchor file, or feature summary.

If no anchor is provided, ask the user for one. Don't guess.

## Output

`.local/<topic-slug>-findings.md`

## Procedure

1. **Read the anchor end-to-end** (if it's a file). Note: scope, requirements, explicit non-goals, ambiguities.

2. **Walk the repo's documentation tree** for rules, decision records, and neighbouring specs that touch the same surface. Adapt to whatever doc layout the repo uses.

3. **Walk the codebase** for:
   - Files referenced by the anchor (read fully)
   - Sibling patterns (similar features, components, schemas)
   - Hidden coupling points (auth scopes, feature flags, schedulers, hooks, migrations)
   - Existing tests covering the surface you'll change

4. **Delegate the walks** when useful, so the orchestrator stays lean.

5. **Write findings** to `.local/<topic-slug>-findings.md` with these sections:

   - **Summary** - 3–5 bullets, your reading of the anchor (surface ambiguities here)
   - **Applicable rules** - quote load-bearing lines, cite by filename
   - **Anchor files** - `path : purpose : what changes`
   - **Sibling patterns** - what to mirror, what to deviate from
   - **Hidden coupling** - anything not in the anchor but the implementer must respect
   - **Open questions** - ambiguities to resolve before planning
   - **Suggested vertical slices** - first-pass decomposition

6. Emit a one-line summary of the artifact and stop. The user will route the findings into a planning phase next.

## Privacy invariants

The findings file lives in `.local/` (gitignored scratch). It is **not** committed. Downstream phases must not reference `.local/` paths in code, comments, commits, or PR bodies - they cite findings by content, not path.
