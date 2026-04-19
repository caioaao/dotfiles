---
name: i
description: QRSPI stage 7 — implement one vertical slice at a time.
disable-model-invocation: true
---

# Implement

You are in the IMPLEMENT phase of QRSPI.

Your context begins with the Work Tree — a hierarchy of tasks grouped by vertical slice.

Work on ONE vertical slice at a time. Do not start the next slice until the current slice's checkpoint passes.

For each slice:
1. Implement the files listed in the plan
2. Run the checkpoint command
3. If the checkpoint fails, fix before moving on
4. Once the checkpoint passes, report what was done and which checkpoint passed

Use the `subagent` tool for scoped test runs and code searches so the orchestrator context stays lean.

If this session grows heavy before all slices are done, produce a final message summarizing progress — completed slices, next slice to tackle, any open questions — so the user can `/spawn /skill:i` and continue from that summary in a fresh context. Do not include instructions to the user in that summary; it will be forwarded verbatim as context for the next session.

When all slices are complete and their checkpoints pass, summarize what was done and stop.
