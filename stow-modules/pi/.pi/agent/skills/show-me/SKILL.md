---
name: show-me
description: Explain the current topic visually - mermaid diagrams that render inline in pi's terminal, plus pseudocode, call trees, component trees, file trees, and shaped diffs. Use when the user says "show me", asks to visualize or diagram something, or when the answer is about structure, flow, or what changes.
---

# Show Me

Answer visually. Pick the smallest view that makes the point. Prose stays short - the visual carries the load, text only labels it.

## Pick the form

**Logic or algorithm -> pseudocode**

```text
on(save)
  if content unchanged
    return cached result
  write new content
  return fresh result
```

**Runtime control flow -> call tree**

```text
submitForm
  createSession
    persistPrompt
    launchAgent
  navigateToSession
```

**UI structure -> component tree** (keep state and module boundaries that matter)

```tsx
<SessionPage> (apps/example/src/routes/session.tsx)
  useSessionEvents()
  <SessionToolbar>
    <RunSkillButton> (packages/ui)
```

**File responsibility or broad refactor -> shallow file tree**

```text
src/
├── commands/    # parses user actions
├── sessions/    # owns session state
└── transport/   # sends API requests
```

**Component interaction, control flow, data flow -> mermaid** (see rules below)

**What changes, when surrounding shape already exists -> diff.** Match diff shape to the topic - component tree, file tree, call tree, or control flow:

```diff
 on(save)
-  write content
+  if content unchanged
+    return cached result
+  write new content
+  invalidate cache
```

**Mostly new code, or the user needs a copyable target shape -> whole block.** Also whole block when omitted context would hide ownership or order.

## Mermaid in pi

Pi renders mermaid fenced blocks inline as Unicode box art (`grok-mermaid`, setting `markdown.mermaid`: `streaming` by default, `final`, or `off`). No browser, no image.

The renderer is all-or-nothing and silent about it. `dist/modes/interactive/components/mermaid.js` drops back to printing raw mermaid source when the diagram does not render, is wider than the message, or carries any parser warning. Three constraints follow.

**1. Only five diagram kinds render.** Anything else prints as raw source - useless to the reader.

| Use | Notes |
| --- | --- |
| `flowchart` / `graph` | `TD`/`TB`/`BT`/`LR`/`RL`, subgraphs, node shapes, dotted/thick links, edge labels |
| `sequenceDiagram` | participants, self-messages, notes, `loop`/`alt`/`opt`, `autonumber` |
| `stateDiagram-v2` | states, transitions, `[*]`, `<<choice>>`, composite states (flattened) |
| `classDiagram` | compartments, annotations, generics, cardinalities, relations |
| `erDiagram` | entities, attributes, crow's-foot cardinalities |

Never emit `gantt`, `pie`, `journey`, `mindmap`, `timeline`, `gitGraph`, `C4Context`, `quadrantChart` here. Want one of those - use a different form, or hand it to the `present` skill.

**2. Too wide = raw source.** Height is free, width is not. Budget is terminal width minus 2 (pi-tui markdown padding), less in fullscreen with a scrollbar. Assume ~76 columns.

- 4 short labels in `flowchart LR` already costs 76 columns. Past ~3 nodes go `TD`.
- Keep labels under ~15 chars. Drop articles, drop types, keep the noun.
- Keep it under ~8 nodes or ~4 participants. More than that means the diagram is answering a question nobody asked.

**3. Any parser warning = raw source.** A settled message prints the source plus `Mermaid diagram not rendered: ...`, even though the art existed. One stray bracket costs the whole diagram, so keep syntax boring:

- Close every `[`, `(`, `{`.
- Quote labels holding special chars: `A["/show-me"]`, `B["latest.png"]`.
- No dangling edge, no half-written last line.
- Skip `style`, `linkStyle`, `click`, `classDef` - no payoff in a terminal.

When a diagram shows up as raw source in the transcript, it hit one of these three. Shrink it or simplify the syntax; don't re-send the same block.

## When terminal art is not enough

Visual UI, layout, dense state comparison, anything needing color or real product styling - do not hand-roll HTML here. Hand it to the `present` skill (`~/.pi/agent/skills/present/SKILL.md`), which owns HTML artifacts, their cache location, and opening them. Say what you want presented and let it run.

## Guidance

- Place each visual next to the short text it supports.
- Keep only the calls, files, props, states, and boundaries needed for the current question or the decision on the table.
- One form is usually enough, several sometimes, all of them never. Don't bury the reader.
