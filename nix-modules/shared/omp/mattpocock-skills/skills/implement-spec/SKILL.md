---
name: implement-spec
description: "Implement a specification in code."
disable-model-invocation: true
---

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The goal is the entire spec integrated on a single integration branch. A PR is an optional publication step, not the deliverable.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

Run independent **implementer subagents** concurrently where the host's delegation policy permits. Follow the host's check policy: implementers and merger subagents skip tests, builds, lint, and formatters when gates belong to the orchestrator; the orchestrator performs only the verification authorized by the agreed testing approach.

## Steps

1. Read the spec, tickets, and configured tracker instructions. Understand the task graph and agree the testing approach: seams, checks, who runs them, and any checks deliberately deferred.

2. If exploration is needed, follow the host's exploration/delegation rules. Share durable findings through context pointers; use a location outside the repo for temporary notes.

3. Create or reuse one integration branch, preserving unrelated work. Name one **integration owner** (the orchestrator or a designated merger subagent); only that owner merges into it. Record its starting commit. Creating a branch does not authorize resetting, discarding work, pushing, or opening a PR.

4. Dispatch ready tickets to **implementer subagents**, each in its own worktree and branch. Before coding, confirm each worktree's actual branch and starting commit against the intended integration base; resolve a mismatch without destroying existing work. Give each implementer the spec/ticket pointers, agreed testing approach, and host gate policy.

5. Before an implementer reports complete, have it integrate the latest integration-branch tip into its ticket branch, preserve unrelated work, and resolve conflicts by intent. It reports the integration commit incorporated, changes, and checks performed or deferred. If the integration branch advances again, the integration owner reconciles that newer tip before merging.

6. The **integration owner** merges each completed ticket into the integration branch. Only after the first successful integrated merge, create a draft PR if the user requests it or the configured tracker requires PR-based closure. Use the configured closure references. Publication still requires the applicable push and external-write authorization; if absent, keep the integrated branch local and report the blocked publication step.

7. As merges change the **frontier**, dispatch newly ready tickets under the same worktree and testing contract. Continue until every ticket and the full spec are integrated.

8. Read and run `/code-review` on the integration branch under the host's delegation/check policy. Fix findings through the same integration owner and reconcile any newer integration tip before reporting complete. The orchestrator performs the authorized integrated verification once all changes have landed; report actual results and any deferred gates.

9. Report the integration branch, incorporated tip, spec/ticket coverage, and verification evidence. If a PR exists and its readiness requirements are met, mark it ready only with the applicable authorization. Without a PR, the integrated branch is still a complete deliverable.

10. Remove only worktrees created for this effort whose work is safely integrated and whose cleanup is authorized; preserve pre-existing resources and unrelated changes.
