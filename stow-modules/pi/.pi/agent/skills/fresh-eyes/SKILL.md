---
name: fresh-eyes
description: Critical review of designs, plans, reasoning, and implementations. Inline tension-based self-review for every task; fresh-context critics via subagent for high-stakes work. Use before presenting a proposal, before executing a plan, after long solo reasoning, on hard-to-reverse decisions, and before declaring work done.
---

# Fresh Eyes

Review work through conflicting perspectives. A critic without your context
judges only what is on the page - you grade your own work with the same context
that produced it.

## When

Rows compose: inline review is always the floor, spawning adds to it. When
unsure whether work is routine, it is not.

| Situation | Action |
|---|---|
| Any non-trivial result, before presenting | Review inline against the tensions |
| New module, public interface, or hard-to-reverse decision (API, schema, auth, migration) | Spawn critic; consider a stronger model |
| Several turns reasoning alone, assumptions unchallenged | Spawn critic on your reasoning |
| Declaring a non-trivial task done | Spawn critic on the diff |
| Two plausible approaches with different trade-offs | Spawn opposing stances |
| Routine task, small fix | Inline only |

## Tensions

Real decisions hide in the conflict between legitimate concerns. Use these axes
as lenses: for each one, generate the questions that matter for *this* task, and
answer them honestly.

- **Change cost vs speed** - what is expensive to reverse, or ripples through
  many places when one concept changes; is paying for flexibility now justified?
- **Thoroughness vs shipping** - what fails silently, regresses, corrupts
  state, or crosses a trust boundary unchecked; which failures are acceptable
  to ship with?
- **Simplicity vs capability** - what existing tool or cheaper version does the
  job, and what is genuinely lost by choosing it?
- **Value vs depth** - does this solve the real problem, proportionally to the
  investment, and how do the people consuming the change experience it?
- **Author vs operator** - how does this reach production and get undone
  (migration, rollout, kill switch); when it fails there, will anyone see it,
  and how will we know it worked?
- **Clarity vs good-enough** - what will the next reader misread or have to
  hold in their head; does one concept keep one name across code, docs, and
  user-facing surface?
- **Ideal vs consistent** - is the right move to match what the codebase
  already does, or to break the pattern deliberately?

## Spawning critics

The critic runs via `subagent` with a fresh context - that is the point. Write
the task self-contained: inline the material under review, absolute paths, and
constraints; it sees none of your conversation. Keep critics read-only
(`tools: ["read", "grep", "find", "ls"]`) so they verify claims against the
repo without acting.

Shape the review to the situation:

- **Single critic** (default) - one reviewer, all tensions.
- **Opposing stances** - contested decision or suspected anchoring: one task
  steelmans the work, one builds the strongest case against; run in parallel.
- **Split by axis** - material too large for one honest pass: a few parallel
  critics, each owning one or two tensions.
- **Different model** - hardest calls: same review, `model` set to a stronger
  or different-family model; cross-model disagreement is real signal.

Write the ask so the report stays useful: few findings, ranked by severity,
each backed by evidence (file:line, quoted passage, or a flagged assumption),
and make explicit that finding nothing significant is a valid, successful
outcome - a critic pushed to always object produces noise instead of signal.
Have severe findings name the cheaper or more reversible alternative when one
exists; an objection without a way out is half a review.

Give the critic what it cannot infer, and steer it toward what you are least
able to see yourself:

- **Design**: constraints, the code it touches, and the simpler alternative you
  rejected - does the rejection hold?
- **Plan / reasoning**: your decision points and rejected alternatives - where
  did you anchor early, and which assumption invalidates the plan if wrong?
- **Implementation**: the diff, the task it serves, how you verified it - what
  breaks outside the diff, and does it do exactly what was asked?

## Acting on reports

- Findings are claims, not orders. Check each against the context the critic
  lacked; act on what survives, dismiss the rest with stated reasons.
- Opposing stances: before acting, state which critique survives the strongest
  point in the work's favor, and why.
- Address severe findings before presenting; carry minor ones as noted
  trade-offs. Re-check fixes inline; spawn again only if the work changed
  shape. An empty report on sound work means the review succeeded - move on.
