---
name: council-of-experts
description: Consult a council of 6 experts (architect, qa, pedantic, product-engineer, hacker, team-player) in parallel. Each expert analyzes the task through their specific lens. Use before proposing multi-module architecture, making irreversible decisions, or validating work.
---

# Council of Experts

Consult multiple expert perspectives in parallel. Each expert analyzes your task through a specific lens, surfacing concerns that a single viewpoint would miss.

## Expert Catalog

| Expert | Lens | Opposes | Aligns With |
|---|---|---|---|
| **architect** | System boundaries, coupling/cohesion, what's hard to change later | hacker, product-engineer | qa |
| **qa** | Edge cases, error handling, silent failures, regression risk, observability | hacker | architect |
| **pedantic** | Naming precision, domain vocabulary, cognitive load, API ergonomics | hacker, product-engineer | team-player |
| **product-engineer** | User value, MVP scope, success metrics, rollout strategy, UX | architect, pedantic | hacker |
| **hacker** | Fastest path, algorithmic approach, leverage existing tools, brute force first | architect, pedantic, qa | product-engineer |
| **team-player** | Codebase consistency, existing patterns, boy scout rule, reversibility | architect | pedantic |

### Tension Axes

Core tensions between experts that produce productive conflict:

```
architect ←→ hacker           (extensibility vs speed)
architect ←→ product-engineer (deep design vs MVP)
architect ←→ team-player      (ideal design vs consistency with existing)
qa ←→ hacker                  (thoroughness vs shipping velocity)
pedantic ←→ hacker            (precision vs "good enough")
pedantic ←→ product-engineer  (naming rigor vs user-facing simplicity)
```

## Selection Algorithm

When choosing experts, follow this algorithm:

1. **Start with the task's primary concern:**
   - Architecture/structure → architect
   - Correctness/safety → qa
   - Clarity/API design → pedantic
   - User-facing feature → product-engineer
   - Performance/speed → hacker
   - Refactoring/existing code → team-player

2. **Add tension** - pick at least one expert that opposes your primary choice:
   - If architect is primary → add hacker or product-engineer
   - If hacker is primary → add architect or pedantic or qa
   - If product-engineer is primary → add architect or pedantic

3. **Avoid redundancy** - don't select experts that align tightly:
   - architect + qa overlap on thoroughness (pick one unless both lenses matter)
   - pedantic + team-player overlap on consistency (pick one unless both lenses matter)
   - hacker + product-engineer overlap on speed (pick one unless both lenses matter)

4. **Limit to 2-4 experts** - more than 4 dilutes focus and wastes context

### Selection Examples

**Architecture review for a new module:**
- Primary: architect
- Tension: hacker (challenge over-engineering)
- Coverage: qa (edge cases + regression)
- → `["architect", "hacker", "qa"]`

**Naming/documentation review:**
- Primary: pedantic
- Tension: product-engineer (challenge naming against user-facing terms)
- → `["pedantic", "product-engineer"]`

**Bug fix validation:**
- Primary: qa
- Tension: hacker (simpler fix?)
- Coverage: team-player (consistent with existing fix patterns?)
- → `["qa", "hacker", "team-player"]`

**New feature proposal:**
- Primary: product-engineer
- Tension: architect (what's hard to change?)
- Coverage: qa (risks), pedantic (API naming)
- → `["product-engineer", "architect", "qa", "pedantic"]`

## Invocation Protocol

After selecting experts, call the `council` tool:

```
council({
  experts: ["architect", "hacker", "qa"],
  task: "Summary of what you want analyzed",
  context: "Relevant code, diff, constraints, or requirements"
})
```

Optional: steer individual experts with `specific_questions`:

```
council({
  experts: ["architect", "hacker"],
  task: "Proposed module: RateLimiter with sliding window...",
  context: "Current codebase uses simple counters...",
  specific_questions: {
    architect: "Is this abstraction justified, or should we extend the existing counter?",
    hacker: "What's the simplest implementation that handles the current traffic?"
  }
})
```

## Output Format

The tool returns a Council Report:

```markdown
# Council Report

**Task:** summary

**Experts consulted:** architect, hacker

## Architect
*Lens: System boundaries, coupling/cohesion, what's hard to change later*

### Observations
...

### Risks / Concerns
...

### Recommendations
...

## Hacker
*Lens: Fastest path, algorithmic approach, leverage existing tools, brute force first*

### Observations
...

### Risks / Concerns
...

### Recommendations
...
```

## Consultation Gates

Consult the council before:

1. Proposing architecture with >1 new module or >3 new files
2. Making irreversible decisions (public API, database schema, auth model)
3. Declaring a task "done" - for final validation

Consider consulting when:

4. Two or more plausible approaches exist with different trade-offs
5. User asks "is this right?" or similar validation-seek
6. You find yourself going deep on one approach without considering alternatives
