---
name: responsibility-driven-design
description: Responsibility-driven design (RDD). Use when deciding which module owns a rule or what another module needs to know, or when asked to review responsibility drift.
---

# Responsibility-Driven Design

**Not my job?** Put each rule with the module that can uphold it. **No need to know?** Pass only the facts the receiver needs to do its job. The workflow below adapts Cockburn's questions for agent work; it is not a transcription of his method.

## Design

1. **Assign ownership before coding.** Read the relevant code and design decisions. Prefer existing modules. For each affected module, finish the sentence “It owns ___ and needs to know ___.” Name the owner of each changed rule or invariant. Record important knowledge the module deliberately leaves to another owner.
2. **Trace success, failure, and a likely change.** Walk the same concrete cases through the proposed interfaces. For each interaction, name the sender, receiver, request, and minimum facts exchanged; show who decides and who handles failure. Use a sequence diagram when order or failure routing matters. For the likely change, distinguish modules that must be edited from those merely called, and say why each edit is needed.
3. **Challenge each decision and dependency.** Ask the two questions above at each interaction. If a caller must learn another module's rules, move the decision behind the owner's interface or explain why the caller legitimately owns it. Finish when every traced decision has an owner and every shared fact has a reason. If materially different allocations remain, use [COMPARE.md](COMPARE.md). Recommend one and put consequential tradeoffs about which future to favor to the user before coding; use the surrounding workflow's decision process.
4. **Record settled constraints.** Follow [Record settled constraints](#record-settled-constraints).

## Record settled constraints

Keep feature-specific decisions in the spec. For one owner, write “`<module>` owns `<rule or invariant>` and needs to know `<facts>`.” When several owners interact, use a compact table with **Owner**, **Owns**, and **Needs to know** columns. Name the interface, the facts that cross it, and any decisions left to another owner where they matter.

For durable ownership or knowledge limits later work needs, update the existing linked design source. If none exists, use a short `DESIGN.md` beside the module and make it discoverable through the project's existing scoped documentation pointer. Use **Owns**, **Collaborates through**, and **Leaves to others** to capture the same constraints.

Link to existing decisions rather than copying them. Use an ADR for the rationale only when it meets the project's ADR criteria; the glossary owns domain terms, not module duties.

## Handoff

- **Brief the slice.** Keep it end to end. Name only the modules it may change, the interfaces it may use, and links to the relevant accepted design constraints.
- **Implement the slice.** Read the accepted constraints before editing. If the slice needs an unagreed owner, interface change, or extra module edit, surface the exact need and smallest proposed change to the integration owner or user before crossing that scope.

## Drift

Compare the diff and affected callers against the accepted responsibility statements. Check each new or moved decision and dependency: did it move ownership, duplicate a rule, or make a caller learn a private fact? Report the hunk, the governing statement, the concrete consequence, and the smallest repair. An explicitly agreed design change calls for checking that its record was updated, not defending the superseded rule. Without an agreed baseline, label any concern as a heuristic, not a drift finding.
