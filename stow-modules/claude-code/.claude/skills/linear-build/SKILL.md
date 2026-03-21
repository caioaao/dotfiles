---
name: linear-build
description: Implement the next unblocked Linear ticket. Reads the ticket from Linear, implements, validates, commits, and marks done. One ticket per iteration. Accepts a ticket ID, project name, or picks the next available ticket.
argument-hint: "[optional: ticket-id e.g. MAIN-123, or project name]"
---

# Build

You are a build agent. Pick the next unblocked ticket from Linear, implement it completely, validate it, commit, update the ticket status, and stop. **One ticket per iteration.**

## Context Gathering

Before starting, read `AGENTS.md` for:
- Project stack and architecture
- Coding guidelines paths (load and follow them before writing code)
- Validation command(s)
- Constraints and conventions
- **Linear team name**

## Step 1: Find the Ticket

### If a ticket ID is provided in `$ARGUMENTS`:

1. Fetch it with `mcp__linear-server__get_issue` (with `includeRelations: true`).
2. If the ticket is already **"In Progress"**, treat this as a **resume** — skip the blocker check and the status update in Step 2 (it's already In Progress). Go straight to loading context and implementing.
3. Otherwise, check that its blocking dependencies are all in a "Done" state. If not, warn the human:
   - **header:** "Blocked" / **question:** "This ticket is blocked by [list of blockers]. They aren't done yet."
   - Options: "Skip to next unblocked ticket", "I'll resolve the dependency first", "Implement anyway (ignore dependency)"

### If a project name or ID is provided in `$ARGUMENTS`:

1. Fetch the project with `mcp__linear-server__get_project` (with `includeResources: true`).
2. First, check for "In Progress" tickets: `mcp__linear-server__list_issues` with `team` from AGENTS.md, `state: "In Progress"`, `project: <project name>`. If one exists, resume it (skip blocker check and status update).
3. If no "In Progress" tickets, list TODO tickets: `mcp__linear-server__list_issues` with `team` from AGENTS.md, `state: "Todo"`, `project: <project name>`.
4. For each candidate, check `mcp__linear-server__get_issue` with `includeRelations: true` to find one that is **not blocked** (all `blockedBy` issues are in a "Done" state).
5. If multiple unblocked tickets exist, pick the highest-priority one. If priorities are equal, pick the one with the fewest dependencies (most foundational).
6. **Advance the picked ticket** to "In Progress": `mcp__linear-server__save_issue` with `id` and `state: "In Progress"`.
7. If no unblocked tickets exist, check if all tickets are Done — if so, output `ALL_TASKS_COMPLETE`. Otherwise, report: "All remaining tickets in this project are blocked. Nothing to implement."

### If NO argument is provided:

1. Query for open tickets: `mcp__linear-server__list_issues` with `team` from AGENTS.md, `state: "Todo"`, `assignee: "me"`.
2. If no results with assignee, try without assignee filter.
3. For each candidate, check `mcp__linear-server__get_issue` with `includeRelations: true` to find one that is **not blocked** (all `blockedBy` issues are in a "Done" state).
4. If multiple unblocked tickets exist, present them to the human:
   - **header:** "Which ticket?" / **question:** "Multiple unblocked tickets available. Which should I work on?"
   - Options: list ticket IDs and titles
5. **Advance the picked ticket** to "In Progress": `mcp__linear-server__save_issue` with `id` and `state: "In Progress"`.
6. If no unblocked tickets exist, report: "All remaining tickets are blocked. Nothing to implement."

## Step 2: Load Context from Linear

Once you have the ticket, load its full context:

1. **Read the ticket description** — this contains the what, why, files to touch, tests to write, and acceptance criteria.
2. **Get the project** (if the ticket belongs to one): `mcp__linear-server__get_project` with `includeResources: true`. Read the project description for high-level context.
3. **Read linked documents** — only fetch documents explicitly referenced in the ticket description or project resources. Don't fetch everything.
4. **Update ticket status** to "In Progress" (skip if already In Progress — i.e., resuming): `mcp__linear-server__save_issue` with `id` and `state: "In Progress"`.

## Step 3: Evaluate Whether to Use `/batch`

After reading the ticket and its context, assess whether the work is **large-scale and parallelizable** — i.e., it touches many independent files or subsystems with similar, repetitive changes.

**Use `/batch` when ALL of these are true:**
- The ticket requires changes to **5+ files** across independent areas of the codebase.
- The changes are **decomposable into independent units** that won't conflict with each other.
- Each unit can be **validated in isolation**.

**If `/batch` is appropriate:**
1. Invoke the `/batch` skill with a clear instruction derived from the ticket description. Include the ticket ID for traceability.
2. After `/batch` completes, proceed to **Step 6** (Commit & Mark Done) — `/batch` handles implementation and validation via parallel agents.

**If `/batch` is NOT appropriate** (most tickets), continue to Step 4.

## Step 4: Implement

1. Read the coding guidelines referenced in AGENTS.md that are relevant to the task.
2. Read any existing code this ticket depends on.
3. Implement the ticket. Write the code, write the tests.
4. Follow the project's conventions and constraints from AGENTS.md.

## Step 5: Validate

Run the validation command from AGENTS.md.

If it fails:
1. Read the error output carefully.
2. Fix the issue.
3. Run again.
4. Repeat until it passes.

**Do NOT commit until validation passes. Do NOT skip it.**

## Step 6: Commit & Mark Done

1. Stage all changed files.
2. Commit with a short imperative message describing what was implemented. Include the ticket ID in the commit message (e.g., "MAIN-123: Add credits_transactions table and schema").
3. **Update ticket status** to "Done": `mcp__linear-server__save_issue` with `id` and `state: "Done"`.
4. **Check if the project is complete:** If the ticket belongs to a project, list remaining tickets with `mcp__linear-server__list_issues` with `project: <project name>`, `state: "Todo"` and `state: "In Progress"`. If none remain (all are Done), mark the project as complete: `mcp__linear-server__save_project` with `state: "completed"`.

## Step 7: Stop

**Stop after one ticket.** The loop orchestrator will invoke you again for the next ticket. Do not continue to the next ticket in the same session.

If you determined in Step 1 that there are no remaining unblocked tickets (whether working from a project or globally), and all tickets are Done, output exactly:

```
ALL_TASKS_COMPLETE
```

## Rules

- **One ticket per iteration.** Never implement more than one ticket.
- **Never skip validation.** The validation gate is non-negotiable.
- **Never commit failing code.** If you can't fix a validation failure after 3 attempts, use `AskUserQuestion`:
  - **header:** "Build failed" / **question:** "Validation failed after 3 attempts: [error summary]. How should I proceed?"
  - Options: "Show me the full error (I'll help debug)", "Skip this ticket and move on", "Abort the build loop"
- **Read before writing.** Understand existing code before modifying it.
- **Small commits.** One ticket = one commit. Don't bundle unrelated changes.
- **No gold-plating.** Implement exactly what the ticket says. No extra features, no premature abstractions.
- **Respect the architecture.** Follow the constraints in AGENTS.md.
- **Always update Linear status.** In Progress when starting, Done when committed.

$ARGUMENTS
