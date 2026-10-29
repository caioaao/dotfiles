---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when discussing codebase terminology, writing or editing a GLOSSARY.md, or recording or editing an ADR.
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline: challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* `GLOSSARY.md` for vocabulary is not this skill: that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)

## File structure

Most repos have a single context:

```
/
├── GLOSSARY.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `GLOSSARY-MAP.md` exists at the root, the repo has multiple bounded contexts. The map points to where each context's glossary lives:

```
/
├── GLOSSARY-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── GLOSSARY.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── GLOSSARY.md
│       └── docs/adr/
```

If these files are absent, proceed silently. Create files lazily: create the relevant `GLOSSARY.md` only when the first term is resolved, and a `GLOSSARY-MAP.md` only when there are actual per-context glossaries to map. If no `docs/adr/` exists, create it when the first ADR is needed.

### Legacy glossary migration

Before creating or updating a glossary, inspect any existing `CONTEXT.md` / `CONTEXT-MAP.md` at the root and in relevant bounded contexts, plus their map targets and incoming references. Classify by content, not filename: a domain vocabulary glossary and a map of those glossaries qualify; general project context, session memory, specifications, and mixed-content documents do not.

For a genuine legacy glossary layout, migrate the root or per-context files to `GLOSSARY.md` and the map to `GLOSSARY-MAP.md` as one cutover. Update every map entry, relative link, reader/writer instruction, and generated pointer (including `docs/agents/domain.md`, `AGENTS.md`, and `CLAUDE.md`) in the same change; leave no old-name aliases or split writers.

Preserve unrelated context documents and their references. Stop the migration and resolve the classification with the user if content is mixed or ambiguous. If a destination already exists, inspect both files: do not overwrite either or choose one silently; resolve conflicting content with the user before moving files. A matching destination still requires an explicit consolidation of all references, not a blind rename.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `GLOSSARY.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account': do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"

### Update GLOSSARY.md inline

When a term is resolved, update the relevant `GLOSSARY.md` right there. Don't batch these up: capture them as they happen. Use the format in [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md).

`GLOSSARY.md` should be totally devoid of implementation details. Do not treat `GLOSSARY.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).
