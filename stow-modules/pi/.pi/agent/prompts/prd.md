---
description: Co-write a PRD interactively — examine anchor, list trade-offs, then draft
argument-hint: "<feature-summary> [anchor-file-or-dir]"
---
Help me write a PRD for: **$1**.

Anchor: `${2:-<ask>}` — if not provided, ask which file or directory anchors this feature before doing anything else.

Work back and forth with me. **Do not draft the PRD until I've answered your structural questions.**

Steps:
1. **Examine the anchor.** Read `$2` (and tightly-coupled neighbours) end-to-end. Identify the current surface, data flow, and entry points.
2. **Scan for constraints.** Research the repo's documentation tree for rules, decision records, and prior specs that touch this surface. Adapt to whatever layout the repo uses.
3. **List technical trade-offs.** 2–4 axes where the design could go different ways (e.g., client-rendered vs backend-resolved, optimistic vs pessimistic updates, sync vs async, feature-flag gating granularity). For each axis, state the options and the cost/benefit.
4. **Ask structural questions** — the ones whose answers shape the PRD. Use the `questionnaire` tool, not free-form prose. Examples:
   - Scope boundaries (what's in / what's out)
   - User-facing acceptance criteria (what "done" looks like to the user)
   - Rollout strategy (flagged? incremental?)
   - Failure modes the design must tolerate
5. **Wait for answers.** Do not assume.
6. **Draft the PRD** to the repo's spec directory (ask if unclear). Filename should be dated (`$(date +%Y-%m-%d)-<slug>.md`). Sections:
   - Context & motivation
   - Goals / Non-goals
   - User stories or acceptance criteria
   - Proposed design (cite anchor files, mirror sibling patterns)
   - Trade-offs considered (the axes from step 3, with the chosen path)
   - Open questions / follow-ups
   - Rollout plan

The PRD is **committed**, so no `.local/` references, no scratch-file leakage, imperative-mood headings.

Arguments: $@
