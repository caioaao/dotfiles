---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask **at most 4 questions per round**, each with your recommended answer, then wait for the user's answers before the next round. When the frontier holds more than 4, ask the ones that unblock the most downstream decisions first; the rest carry over to a later round.

Ask through your harness's structured question tool when it has one (`ask`, `AskUserQuestion`, or similar), the whole round in a single call:

- The question title goes in the short header/label; the body goes in the question text.
- The choices become 2–5 options, each with its tradeoff in a one-line description. The tool adds a free-text "Other" itself; never add one.
- Mark your recommended answer: use the tool's recommended/default field if it has one, otherwise list it first and suffix its label with "(Recommended)".
- A question with no natural choices still gets options: your recommended answer plus the strongest alternatives, leaving "Other" for the rest.
- Use multi-select only when the options genuinely combine.

Without such a tool, number the questions and format the round as plain text:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; fill this round from the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
