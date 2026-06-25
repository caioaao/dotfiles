---
name: delegating-to-subagents
description: Write effective subagent delegations. Read before using the `subagent` tool so each task carries a clear objective, output format, tool grant, and boundaries. Use whenever you fan out recon, research, or scoped edits to subagents.
---

# Delegating to subagents

A subagent is a fresh `pi` process with an isolated context window. It cannot see
your conversation, it loads no context files (AGENTS.md), and it cannot spawn its
own subagents. The task prompt is the only thing that governs it. Treat every
delegation as a contract with four required parts.

## The delegation contract

Each task must specify:

1. **Objective** - the single concrete goal. One task, one objective. If you find
   yourself writing "and also", split into separate tasks.
2. **Output format** - the exact shape you want back (e.g. "return a JSON array of
   `{file, line, finding}`", or "list `path:line - one-line description`"). The
   parent only sees the subagent's final text; an unstructured answer is hard to
   consume.
3. **Tool / source guidance** - which files, directories, or commands to use, and
   what to ignore. This is *prose* in the task. It is NOT the same as the schema
   `tools` field (see below). Point the subagent at the right starting files so it
   does not waste turns searching.
4. **Boundaries** - what is in scope and explicitly out of scope; whether it may
   modify files or must stay read-only; stop conditions. Without boundaries a
   subagent over-reaches or rabbit-holes.

## Tools: capability grant vs guidance

Two different levers share the word "tools". Do not confuse them:

- **Schema `tools` field** = a hard capability grant (an allowlist for that task).
  - **Omit it for the permissive default**: every tool EXCEPT `subagent`,
    `council`, `questionnaire`, `spawn_session`. This is what research, web-search,
    and CLI/doc-gathering tasks want - they get `bash`, skills, and file tools out
    of the box.
  - Provide an explicit list only to **narrow** a task, e.g.
    `tools: ["read", "grep", "find", "ls"]` for read-only recon that must not write
    or shell out.
  - `subagent`/`council`/`questionnaire`/`spawn_session` are always rejected
    (recursion/escape prevention), even if listed.
  - `bash` is available by default; it is how subagents run web searches and CLIs.
    It is also the only process-spawning tool, so recursion prevention is
    best-effort - narrow a task to a no-bash list when shell access is unnecessary.
- **Prose tool/source guidance** (contract part 3) = advice inside the task string
  about which sources/commands to consult. It does not change capabilities.

Default to the permissive set for research; narrow only when a task should be
constrained (e.g. read-only audits).

## Self-contained tasks

Because subagents load no context files and cannot see your conversation:

- Inline every fact they need: absolute paths, the cwd, relevant constraints,
  naming conventions, build/test commands.
- Do not reference "the spec above" or "as we discussed" - they have no "above".

## Template

```
Objective: <one concrete goal>.
Context: <cwd, key files with absolute paths, constraints>.
Do: <steps / where to look>.
Do NOT: <out-of-scope, read-only vs may-modify>.
Output: <exact format you want back>.
```

## Examples

Research / web search (default tools - omit `tools`):

```
subagent { tasks: [{
  label: "docs-lookup",
  task: "Objective: find the current recommended way to configure X in library Y.
         Context: use the brave-search skill / curl to fetch official docs.
         Do: search, open the authoritative source, extract the config snippet.
         Do NOT: guess from memory; cite the URL you used.
         Output: the config snippet plus the source URL."
}]}
```

Read-only recon (narrowed - no shell, no writes), structured output:

```
subagent { tasks: [{
  label: "auth-recon",
  task: "Objective: map how session tokens are validated.
         Context: Elixir repo at /abs/path. Start in lib/app/auth/.
         Do: trace the validation call path; note file:line for each step.
         Do NOT: modify files; do not inspect the frontend.
         Output: ordered list of `file:line - what happens`.",
  tools: ["read", "grep", "find", "ls"]
}]}
```

Scoped fix (default tools already include edit/write/bash):

```
subagent { task:
  "Objective: fix the failing test test/app/auth_test.exs:42.
   Context: /abs/path; run tests with `mix test`.
   Do: read the test + impl, make the minimal change, re-run that test file.
   Do NOT: touch unrelated files; do not refactor.
   Output: summary of the change as `file - what changed` and the test result."
}
```

## Reminders

- One objective per task. Split compound work into parallel tasks or a chain.
- Subagents cannot delegate further - keep each task at a size one agent can finish.
- Prefer parallel `tasks` for independent recon; use `chain` with `{previous}` when
  step N needs step N-1's output.
