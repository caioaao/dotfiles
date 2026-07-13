---
description: Load context bundle scoped to an intent, then act on it
argument-hint: "[intent]"
---
Load the agent context bundle scoped to the intent below, then act on it.

<intent>$@</intent>

If the intent is empty: survey what work is active and relevant to this
working tree.

1. Load the `context` skill and follow its read protocol.
2. Interpret the intent - free-form, no fixed grammar. Common shapes and
   their retrieval profiles:
   - **question** ("answer: ...", "what/which/where...") - broad + shallow.
   - **next task** (optionally naming a project) - narrow + deep: that
     project's plans, checklists, handoffs. Identify the next task, why it
     is next, what done looks like.
   - **planning** - narrow + deep: current state, constraints, open
     questions - gathered as input for the planning that follows.
   - **survey / this worktree** - broad + shallow: cross-reference pwd,
     remote, branch against docs; list what applies.
   Blend profiles when the intent spans shapes.
3. Gather first, act second: do not start executing the intent until context
   is loaded.
4. Finish with a short context brief - what was loaded, current state, open
   questions - then act on the intent: answer directly, proceed to planning,
   or propose the next step and confirm with me before executing.
