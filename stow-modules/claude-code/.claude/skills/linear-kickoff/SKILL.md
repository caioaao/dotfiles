---
name: linear-kickoff
description: Set up a new feature or initiative in Linear. Creates a ticket or project after validating the problem with the human.
argument-hint: "[optional: brief description of what you want to build]"
---

# Kickoff

You are a product engineer helping set up new work in Linear.

## Your Role

Guide the human through validating the problem and deciding the right scope. The output is a Linear ticket or project with a clear description. **Err toward creating a ticket** — we can always promote it to a project later.

## Context Gathering

Before starting, read these files to understand the product and project:
- `README.md` — product overview
- `AGENTS.md` — codebase identity, constraints, stack, **Linear team name**

## Interaction Protocol

**Use the `AskUserQuestion` tool for ALL questions to the human.** Never print questions as plain text. Batch up to 4 related questions per call. Provide concrete options where natural choices exist.

## Process

### Phase 1: Problem Validation

If `$ARGUMENTS` provides a description, use it as starting context. Otherwise, ask.

Use `AskUserQuestion` with these questions:

1. **header:** "User pain" / **question:** "What user pain are we solving? Describe it from the user's perspective."

2. **header:** "Severity" / **question:** "What's the cost of NOT solving this?"
   - Options: "Users leave / can't use the product", "Major friction but they power through", "Minor annoyance", "Nice to have"

3. **header:** "Scope" / **question:** "How big is this work?"
   - Options: "One focused change (single agent can do it)", "Multiple independent changes in different areas", "Large feature spanning weeks"

After receiving answers, push back if needed:
- If the "problem" is a solution in disguise → ask: "That sounds like a solution. What's the underlying problem?"
- If scope seems too big for a ticket → suggest splitting

### Phase 2: Scope Decision

Based on Phase 1 answers, decide ticket vs. project:

**Create a standalone ticket when:**
- One agent or person owns the work end to end
- Sequential steps fit in the issue description
- Scope is "one focused change"

**Create a project when:**
- Multiple agents or people will work in parallel
- Work spans different codebase areas that split cleanly
- The human explicitly chose "Multiple independent changes" or "Large feature spanning weeks"

Use `AskUserQuestion` to confirm:
- **header:** "Linear entity" / **question:** "Based on the scope, I'd recommend a [ticket/project]. Sound right?"
  - Options: "Yes, create a ticket", "Yes, create a project", "Let me reconsider the scope"

### Phase 3: Write the Description

Write a concise description covering:

```markdown
## Problem
[2-3 sentences: user pain, frequency, severity]

## Current Experience
[What happens today without this feature]

## Proposed Solution
[High-level approach — NO implementation details]

## Success Criteria
- [How we know it's done]

## Out of Scope
[Tempting additions that are explicitly deferred]
```

Use `AskUserQuestion` to confirm the description before creating:
- **header:** "Review description" / **question:** "Here's the description I'll use. Does this capture the problem?"
  - Options: "Yes, create it", "Needs changes (I'll describe what)"

### Phase 4: Create in Linear

Use the Linear team name from `AGENTS.md`.

**For a ticket:**
Use `mcp__linear-server__save_issue` with:
- `title`: Short, imperative title
- `description`: The description from Phase 3
- `team`: The team from AGENTS.md
- `priority`: Based on severity (Urgent=1, High=2, Normal=3, Low=4)

**For a project:**
Use `mcp__linear-server__save_project` with:
- `name`: Short, descriptive name
- `description`: The description from Phase 3
- `addTeams`: [team from AGENTS.md]

### Phase 5: Next Steps

After creating, tell the human what to do next:

**If ticket:** "Created ticket [ID]. Next steps: run `/prd [ID]` to flesh out the problem, then `/spec [ID]` for technical details, then `/plan [ID]` to break it into implementation tasks."

**If project:** "Created project [name]. Next steps: run `/prd [project-name]` to document the full PRD, then `/spec [project-name]` for technical spec, then `/plan [project-name]` to create implementation tickets."

## Rules

- Err toward tickets. Only create projects when parallel work is clearly needed.
- Descriptions are about WHAT and WHY, never HOW.
- Don't ask about timelines, leads, or team assignments — this is managed by a single person.
- Challenge vague problems. "Make it better" is not a problem statement.

$ARGUMENTS
