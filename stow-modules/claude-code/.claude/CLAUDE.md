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

## CRITICAL: Planning Protocol

**YOU MUST call personality agents BEFORE and AFTER every non-trivial planning phase.**

Skip only for truly trivial tasks (typo fixes, obvious one-liners).

### Before Planning
- Consult agents to explore the problem from different angles
- Seek opposing perspectives—don't just confirm your initial intuition
- Scale agent count to task complexity (1-3 agents)

### After Planning
- Validate the plan with agents that might challenge your approach
- Revise based on feedback before implementation

### The Principle
Good decisions emerge from tension between perspectives. If all your consulted agents agree, you probably picked agents that think like you already do. Seek the uncomfortable perspective.

## Examples: Seeking Opposing Perspectives

**Example 1: New Feature**
- Before: Product Engineer ("What's the user problem?") + Architect ("What's hard to change later?")
- Tension: PE wants MVP simplicity, Architect wants extensible design
- After: QA ("How do we test this?") challenges both with edge cases

**Example 2: Performance Fix**
- Before: Hacker ("What's the fastest path?") + Architect ("Will this create tech debt?")
- Tension: Speed vs long-term maintainability
- After: Team Player ("Does this match our patterns?") keeps it consistent

**Example 3: Bug Fix**
- Before: Hacker ("Quick fix?") + QA ("What's the real root cause?")
- Tension: Ship fast vs fix properly
- After: Pedantic ("Is the naming clear?") catches confusing code

**Example 4: Code Review**
- Team Player + Pedantic + QA in parallel
- Each catches different issues: consistency, precision, test gaps

## Intuition Aids

When unsure which agents to consult, these signals can help:

- Complexity smell → consider Pedantic, Architect
- Consistency question → consider Team Player
- "Is this worth building?" → consider Product Engineer
- Testing gap → consider QA
- Need it fast → consider Hacker

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

- **CRITICAL**: For non-trivial tasks, NEVER plan without consulting agents first
- **CRITICAL**: Seek opposing perspectives, not just validation
- If all agents agree easily, you haven't challenged your thinking enough
- Synthesize conflicts—that's where good decisions emerge
- If you catch yourself planning without agents, STOP and invoke them
