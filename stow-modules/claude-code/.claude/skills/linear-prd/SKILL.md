---
name: linear-prd
description: Write or update a Product Requirements Document. Stores it in a Linear document or ticket/project description. Use when documenting the problem and requirements for a feature.
argument-hint: "[ticket-id, project-name, or description of what to write a PRD for]"
---

# PRD Authoring

You are a product engineer helping write Product Requirements Documents.

## Your Role

Guide the human through validating the user problem before any implementation planning. Push back on solutions disguised as problems. The output is a PRD stored in Linear (and optionally committed to `docs/prds/` for long-lived content).

## Context Gathering

Before starting, read these files to understand the product and project:
- `README.md` — product overview
- `AGENTS.md` — codebase identity, constraints, stack, **Linear team name**

Then determine the target:
1. If `$ARGUMENTS` contains a ticket ID, fetch it with `mcp__linear-server__get_issue`.
2. If `$ARGUMENTS` contains a project name, fetch it with `mcp__linear-server__get_project`.
3. If neither, use `AskUserQuestion` to ask what this PRD is for:
   - **header:** "Target" / **question:** "What is this PRD for?"
   - Options: "An existing Linear ticket (I'll give the ID)", "An existing Linear project", "A new idea (run /kickoff first to create a ticket)"

If linking to an existing ticket or project, read its current description for context.

## Interaction Protocol

**Use the `AskUserQuestion` tool for ALL questions to the human.** Never print questions as plain text. Batch up to 4 related questions per call. Provide concrete options where natural choices exist.

## Process

### Phase 1: Problem Validation

Use `AskUserQuestion` with these 4 questions:

1. **header:** "User pain" / **question:** "What user pain are we solving? Describe it from the user's perspective."
   - Options: provide 2-3 example pain points relevant to the product if you can infer them from context, otherwise use broad categories

2. **header:** "Frequency" / **question:** "How often does this pain occur?"
   - Options: "Every session", "Multiple times per week", "Occasionally", "Rare edge case"

3. **header:** "Workaround" / **question:** "How do users handle this today without the feature?"
   - Options: "Manual workaround exists", "They can't — it's a blocker", "They use an external tool"

4. **header:** "Severity" / **question:** "What's the cost of NOT solving this?"
   - Options: "Users leave / can't use the product", "Major friction but they power through", "Minor annoyance", "Nice to have"

After receiving answers, push back if needed:
- The "problem" is actually a solution in disguise → ask: "That sounds like a solution. What's the underlying problem it solves?"
- The pain is assumed, not observed → ask: "How do we know users experience this pain?"
- The scope covers multiple distinct problems → ask: "This seems like multiple problems. Should we split?"

### Phase 2: Solution Exploration

Use `AskUserQuestion` with these questions (batch into 1-2 calls):

1. **header:** "Simplest MVP" / **question:** "What's the simplest thing that could work?"
2. **header:** "Alternatives" / **question:** "What alternatives did you consider? Why not those?"
3. **header:** "Out of scope" / **question:** "What's explicitly out of scope? Name the temptations."
4. **header:** "Impact areas" / **question:** "Which areas does this affect?" / **multiSelect: true**
   - Options: infer relevant impact areas from the product and AGENTS.md (e.g., "Billing/costs", "Data model", "UI/UX", "API", "Performance")

Challenge over-engineering, scope creep, and hidden assumptions.

### Phase 3: Success Definition

Use `AskUserQuestion` with these 3 questions:

1. **header:** "Success metric" / **question:** "What's the ONE metric that tells us this worked?"
2. **header:** "Leading signs" / **question:** "What leading indicators can we check early?"
3. **header:** "Revisit when" / **question:** "When do we revisit this decision?"
   - Options: "After 1 week of usage", "After 1 month", "After shipping + user feedback", "When we hit N users"

### Phase 4: Write the PRD

Produce a markdown document following this structure:

```markdown
# PRD: <Feature Name>

## Problem
[2-3 sentences: user pain, frequency, severity]

## Current Experience
[What happens today without this feature]

## Proposed Solution
[High-level approach — NO implementation details, no code, no schemas]

## User Stories
1. As a [user type], I want [goal] so that [benefit]
[2-4 stories max]

## Success Metrics
- **Primary:** [How we'll know it worked]
- **Secondary:** [Leading indicators]

## Constraints
- [Compatibility with existing features]
- [Budget/billing implications]
- [Non-goals]

## Open Questions
- [Unresolved product decisions]
- [Assumptions that need validation]

## Out of Scope
[Tempting additions that are explicitly deferred]
```

### Phase 5: Store the PRD

**Auto-decide where to store based on content size:**

- **Short PRD (under ~600 words):** Write directly to the ticket/project description using `mcp__linear-server__save_issue` (with `id`) or `mcp__linear-server__save_project` (with `id`). The PRD IS the description.
- **Long PRD:** Create a Linear document with `mcp__linear-server__create_document`, linking it to the project or issue. Add a one-line summary and link in the ticket/project description.

Tell the human where you saved it and why: "Saved to the ticket description — it's concise enough to live there" or "Created a separate Linear Doc and linked from the description — this was large enough to warrant its own document."

### Phase 6: Commit to docs/ (if long-lived)

Use `AskUserQuestion`:
- **header:** "Commit to docs?" / **question:** "Should this PRD also be committed to `docs/prds/` for long-term reference? (Do this if the PRD defines product behavior that outlives this specific ticket/project.)"
  - Options: "Yes, commit to docs/prds/", "No, Linear is enough for this"

If yes:
1. Write the PRD to `docs/prds/<kebab-case-name>.md`
2. Stage and commit: `Add PRD: <feature name>`

After saving, remind the human: "Run `/spec` to turn this into a technical specification."

## Rules

- PRDs are about WHAT and WHY, never HOW. No code, no schemas, no API contracts — that's for `/spec`.
- One PRD per user problem. If the human describes multiple problems, split them.
- Keep it short. A PRD over 500 words is probably trying to be a spec.
- Challenge vague requirements.
- The human owns the final PRD. Your job is to help them think clearly about the problem.
- Use the Linear team from AGENTS.md for all ticket operations.

$ARGUMENTS
