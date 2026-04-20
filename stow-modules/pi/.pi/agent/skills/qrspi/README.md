# QRSPI

An 8-stage workflow for AI coding agents, based on [Dex Horthy's QRSPI](https://x.com/dexhorthy).

## Stages

| # | Skill | Phase | What it does |
|---|-------|-------|--------------|
| 1 | `q` | Alignment | Generate 10–20 technical questions from a feature ticket |
| 2 | `r` | Alignment | Gather objective codebase facts answering those questions |
| 3 | `d` | Alignment | Brain-dump design doc for user review |
| 4 | `s` | Alignment | Signatures, types, and vertical slices with checkpoints |
| 5 | `p` | Alignment | Tactical implementation plan per vertical slice |
| 6 | `wt` | Execution | Organize tasks into a work tree |
| 7 | `i` | Execution | Implement one vertical slice at a time |

## Usage

Start with a ticket:

```
/skill:q Build a rate-limiter middleware for the /api/upload endpoint
```

Then hand off to each subsequent stage with `/spawn`:

```
/spawn /skill:r
/spawn /skill:d
/spawn /skill:s
/spawn /skill:p
/spawn /skill:wt
/spawn /skill:i
```

Each `/spawn` starts a fresh session seeded with only the previous stage's final output. The user controls when to advance — review and iterate within a stage before moving on.

## How it works

**Phase handoff via `spawn`.** Each stage produces a single final message as its deliverable. `/spawn /skill:<next>` forwards that message to a new session with a clean context. No files are written between phases — the assistant's last message *is* the artifact.

**Subagents as context firewalls.** The Research stage dispatches one `researcher` subagent per question. Each subagent burns its own context on investigation and returns a condensed answer. The Implement stage uses subagents for scoped test runs. This keeps the orchestrator's context lean.

**Context discipline.** Target < 40% context utilization per session, restart at 60%. The `i` skill supports self-continuation: if the session grows heavy mid-implementation, it produces a progress summary that can be `/spawn /skill:i`'d into a fresh context.

## Key design choices

- **No intermediate files.** Handoff is structural (spawn), not disk-based.
- **Ticket hidden from Research.** Because spawn only forwards the questions list (not the original ticket), Research produces objective facts rather than confirmation-biased answers.
- **`disable-model-invocation: true`** on all skills. They stay out of the system prompt and are only activated when the user explicitly invokes them.

## Dependencies

- [`researcher` agent](../../agents/researcher.md)
- [`spawn` extension](../../extensions/spawn.ts)
- [`subagent` extension](../../extensions/subagent)
