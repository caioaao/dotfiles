---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Before coding, resolve every provided ticket reference through the configured tracker instructions and fetch its actual title and body. State the fetched title alongside its reference, then use its requirements and acceptance criteria to scope the work. If a reference cannot be resolved, report that blocker rather than coding against a guessed identity. Read a provided spec directly when no ticket is involved.

Load TDD explicitly with `read` at `skill://tdd`; use it where possible, at pre-agreed seams.

Follow the host's delegation and verification ownership rules. Run typechecking and focused tests during implementation, and the full suite at the end, only when those checks are authorized and assigned to you; otherwise hand the concrete checks to their owner without running them.

Once the work is implemented, load the review instructions with `read` at `skill://code-review` and complete both applicable review axes under the host's delegation rules.

Commit only when authorized. This workflow grants no implicit authority to push or open a PR.
