---
name: to-tickets
description: Break a plan, spec, or conversation into tracer-bullet tickets on the configured tracker, with explicit blockers and the source issue as their parent when one exists.
disable-model-invocation: true
---

# To Tickets

Break a plan, spec, or conversation into a set of **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it.

The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`. Resolve the `ready-for-agent` role through that vocabulary, preserving configured label overrides.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Give each ticket its **blocking edges**: the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a ticket blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify ticket; green is promised only there.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct: does each ticket only depend on tickets that genuinely gate it?
- Should any tickets be merged or split further?

Iterate until the user approves the breakdown.

### 5. Publish the tickets to the configured tracker

Publish the approved tickets using the configured tracker's operations. Treat **parentage** (which effort a ticket belongs to) and **blocking** (what must finish before it can start) as separate relationships: being a sub-issue does not make a ticket blocked by its parent or siblings. If the source was an existing issue, make it the parent of every new ticket, using native parentage where supported and a body reference otherwise.

- **Local files** → write one file per ticket under `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Reference only existing source/blocker files by their repo-relative paths, using the configured tracker's `Part of:` and `Blocked by:` conventions. Maintain its ordered source-child index where required. Use the per-ticket file template below: one ticket per file, never a single combined file.
- **A hosted issue tracker (GitHub, Linear, …)** → create one issue per ticket in dependency order (blockers first), retaining each returned identifier before referencing it. Attach the tickets to their source parent where one exists. Separately create native blocking edges for the approved dependencies; a sub-issue link is not a blocking edge. Where either relationship is unsupported, use the corresponding body fallback below. Apply the configured `ready-for-agent` role label.

Work the **frontier**: any ticket whose blockers are all done. For a purely linear chain that means top to bottom.

Preserve the source parent's existing status, title, and content; only attach the approved children, updating a dedicated child index when the tracker's fallback requires it. Do not close or reopen it as part of ticket publication.

<local-ticket-template>

# <NN>: <Ticket title>

**Part of:** the existing source issue or spec's repo-relative path, if there is one; otherwise omit this line.

**What to build:** the end-to-end behaviour this ticket makes work, from the user's perspective, not a layer-by-layer implementation list.

**Blocked by:** repo-relative paths of existing tickets that gate this one, or `none`.

**Status:** <configured label for the ready-for-agent role>

- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

</local-ticket-template>

<issue-template>

## Parent (only when native parentage is unavailable)

Reference the existing source issue using the configured tracker's parentage body convention. Omit this section when the source was not an issue or the tracker already records it as the native parent.

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by (only when native blocking is unavailable)

Reference each blocking ticket, or write "None (can start immediately)". Omit this section when native edges carry the dependencies; keep the relationship in one place.

</issue-template>

In either form, avoid specific implementation file paths or code snippets: they go stale fast. Tracker record links and local parent/blocker paths are required relationship references, not implementation detail. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.
