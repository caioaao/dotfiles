# Compare responsibility allocations

Use two viable designs that assign at least one consequential rule or fact to different owners. Reuse alternatives the surrounding workflow already produced. Trace the same success, failure, and likely change for each design.

These are operational readings of the six tests, not a scoring system from the book. For each test, mark each design **supported**, **costly**, or **unknown** for the stated scenarios and cite the interaction or edit that earns the rating. Do not total the ratings.

| Test | Evidence to look for |
| --- | --- |
| Abstraction | Which implementation decisions can change without changing what a caller must know? |
| Responsibility Alignment | Can the module charged with the rule enforce it without another module duplicating the decision? |
| Evolution | Which modules and interfaces need edits for the expected change, and why? |
| Communication Patterns | Which requests, round trips, ordering constraints, or failure paths couple the modules? |
| Data Connectedness | Which data must stay consistent or be joined across modules, and who owns that relationship? |
| Data Variations | What must change when a supported data shape, representation, or source varies? Who absorbs it? |

Recommend the design that best protects the expected changes. Name the future the other design handles better and the assumption that would reverse the recommendation.
