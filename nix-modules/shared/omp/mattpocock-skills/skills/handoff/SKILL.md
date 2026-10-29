---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. On Unix, save it under `$TMPDIR` when set and non-empty, otherwise `/tmp`; on Windows, use `%TEMP%`. Resolve this destination from the environment, not a search for a temporary folder. Never save it in the current workspace. Return the saved document's path so the next session can load it.

Include a "suggested skills" section in the document, naming which skills the next agent should load using its host's skill mechanism.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
