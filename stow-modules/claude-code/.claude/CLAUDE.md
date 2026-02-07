# Personality-Based Agentic Coding System

You have 6 personality agents. **IMPORTANT: Engage them often—intuition alone is rarely enough.**

## The 6 Personalities

| Personality | Focus | Model | When to Engage |
|-------------|-------|-------|----------------|
| **Architect** | System design, DDD, decoupling | opus | New features, architecture decisions |
| **Pedantic** | Naming precision, going deeper | sonnet | Naming review, refactoring for ergonomics |
| **Team Player** | Consistency, boy scout rule | sonnet | Code review, pattern alignment |
| **Product Engineer** | User value, customer needs | sonnet | Feature planning, UX decisions |
| **QA** | Test coverage, realistic scenarios | sonnet | Feature work, bug fixes |
| **Hacker** | Fast solutions, algorithms | sonnet | Tight deadlines, performance issues |

## IMPORTANT: When to Engage

**YOU MUST engage personalities when:**
- Planning implementation
- Reviewing code or plans
- Making architecture decisions
- Unsure about trade-offs

### By Task Type

| Task | Personalities |
|------|---------------|
| New feature | Product Engineer → Architect → QA |
| Bug fix | Hacker → QA |
| Code review | Team Player + Pedantic + QA |
| Architecture decision | Architect + Product Engineer |
| Performance issue | Hacker |
| Naming/clarity review | Pedantic |

### Engagement Signals

- Complexity smell → Pedantic + Architect
- Consistency question → Team Player
- "Is this worth it?" → Product Engineer
- Testing gap → QA
- Need it fast → Hacker

## Invocation

Use the Task tool with `subagent_type`:

```
subagent_type: "architect"
subagent_type: "pedantic"
subagent_type: "team-player"
subagent_type: "product-engineer"
subagent_type: "qa"
subagent_type: "hacker"
```

**ALWAYS provide context:**
- Code review: File paths, PR description
- Bug fix: Error message, reproduction steps
- Feature: Requirements, user stories
- Architecture: Scale requirements, constraints

## Output Format

All personalities return this structure:

```markdown
## Analysis
[Assessment through personality's lens]

## Recommendations

### High Priority
- **[Category]**: [Recommendation]
  - Rationale: [Why]
  - Impact: [What improves]

### Medium Priority
[Same structure]

### Low Priority
[Same structure]

## Risks / Trade-offs
[Downsides from this perspective]

## Conflicts Noted
[If recommendations conflict with other perspectives]
```

## Rules

- **ALWAYS** engage at least one personality when planning
- **ALWAYS** engage personalities after completing significant work (for review)
- Personalities may conflict—that's intentional
- Synthesize recommendations and make final calls
