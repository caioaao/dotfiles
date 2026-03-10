---
name: ralphio-bootstrap
description: Bootstrap Ralph loops in your project. Generates all artifacts (AGENTS.md, prompts, loop.sh) in the correct order. One command to go from nothing to working loop.
bootstrap_order: 0
---

# Bootstrap Ralph Loops

## What This Skill Does

Sets up Ralph loops (autonomous AI coding) in your project by generating all required artifacts in the correct order. This is the primary entry point for new users.

**One command → working loop.**

## What Gets Generated

| Step | Artifact | Purpose |
|------|----------|---------|
| 1 | `AGENTS.md` | Project context for all AI sessions (~40-60 lines) |
| 2 | `PROMPT_spec.md` | Interactive spec writing prompt |
| 3 | `PROMPT_plan.md` | Planning mode prompt for gap analysis |
| 4 | `PROMPT_build.md` | Build mode prompt (one task per iteration) |
| 5 | `loop.sh` | Orchestration script |

## How to Use This Skill

### Option A: Generate All (Recommended for New Projects)

Generate all 5 artifacts in sequence:

1. Study the target project thoroughly
2. Generate `AGENTS.md` — project identity, validation commands, constraints
3. Generate `PROMPT_spec.md` — tailored for this project's domain
4. Generate `PROMPT_plan.md` — with correct source paths and validation commands
5. Generate `PROMPT_build.md` — with backpressure gates from AGENTS.md
6. Generate `loop.sh` — configured for this project's CLI and model preferences

Show progress as you go:
```
[1/5] Generating AGENTS.md... done
[2/5] Generating PROMPT_spec.md... done
[3/5] Generating PROMPT_plan.md... done
[4/5] Generating PROMPT_build.md... done
[5/5] Generating loop.sh... done
```

### Option B: Selective Generation

If some artifacts already exist, skip them:
- "Generate only PROMPT_plan.md and PROMPT_build.md" — user already has AGENTS.md
- "Regenerate loop.sh" — user changed CLI preferences

For selective generation, use the individual skills:
- `ralphio-generate-agents`
- `ralphio-generate-spec`
- `ralphio-generate-plan`
- `ralphio-generate-build`
- `ralphio-generate-loop`

## Before Bootstrapping

Study the target project to understand:

- **Project identity** — what it is, where it's deployed
- **Tech stack** — language, framework, build system
- **Directory structure** — source paths (not all projects use `src/`)
- **Validation commands** — build, test, lint scripts
- **Git conventions** — commit style, branch strategy
- **CLI preferences** — which AI tool (claude), model preferences
- **Existing artifacts** — check for existing AGENTS.md, specs/, prompts

## Bootstrap Order Matters

Later generators benefit from earlier outputs:

```
AGENTS.md ──────────────────────────────────────┐
    │                                           │
    ▼                                           │
PROMPT_spec.md                                  │
    │                                           │
    ▼                                           │
PROMPT_plan.md ◄── reads AGENTS.md for ─────────┤
    │              validation commands          │
    ▼                                           │
PROMPT_build.md ◄── reads AGENTS.md for ────────┘
    │               backpressure gates
    ▼
loop.sh ◄── references prompt file names
```

**Key insight:** AGENTS.md provides validation commands that become backpressure gates in the plan and build prompts. Generate it first.

## After Bootstrap: What's Next

Once all artifacts are generated, show the user their next steps:

```
Your Ralph loop is ready!

Files generated:
  AGENTS.md        — Review and customize project constraints
  PROMPT_spec.md   — Use interactively to write requirement specs
  PROMPT_plan.md   — Used by loop.sh in plan mode
  PROMPT_build.md  — Used by loop.sh in build mode
  loop.sh          — Orchestration script

Next steps:
  1. Review AGENTS.md — add any missing constraints or validation commands
  2. Write specs:      claude --prompt PROMPT_spec.md
  3. Run planning:     ./loop.sh plan
  4. Start building:   ./loop.sh build

The loop will:
  - Select highest-priority task from IMPLEMENTATION_PLAN.md
  - Implement it completely
  - Run validation (build/test/lint)
  - Commit and push
  - Repeat until all tasks are done
```

## Design Principles

### Generate-Then-Own
Each artifact is generated once and owned by the user. ralphio does not update, patch, or version generated artifacts. Customize freely.

### Self-Contained Artifacts
Each generated file contains everything it needs. No imports, no cross-file references that could break. PROMPT_plan.md doesn't `#include` from AGENTS.md — it embeds the validation commands directly.

### Study Before Generating
Every generator studies the target project before producing output. Discovery over assumption. Don't generate generic artifacts — tailor them to this specific project.

### Duplication Over Indirection
When two artifacts must agree on a format (e.g., IMPLEMENTATION_PLAN.md structure), the convention is stated in both independently. This optimizes for LLM context quality — each prompt is complete in isolation.

## Troubleshooting

### "AGENTS.md is empty/generic"
The generator didn't find enough project context. Check:
- Does the project have a README?
- Are there build/test scripts in package.json, Makefile, etc.?
- Run `ralphio-generate-agents` again after adding project documentation.

### "Validation commands are wrong"
Edit AGENTS.md directly — you own it. Then regenerate PROMPT_plan.md and PROMPT_build.md to pick up the changes (or edit them directly too).

### "loop.sh uses wrong CLI flags"
Edit loop.sh directly. Common adjustments:
- Model selection (`--model opus` vs `--model sonnet`)
- Permission flags (`--dangerously-skip-permissions`)
- Output format (`--print` vs default)

### "I only want to regenerate one artifact"
Use the individual skills:
- `ralphio-generate-agents` — just AGENTS.md
- `ralphio-generate-plan` — just PROMPT_plan.md
- etc.

## Individual Skills Reference

For expert use or selective regeneration:

| Skill | Generates | When to Use |
|-------|-----------|-------------|
| `ralphio-generate-agents` | AGENTS.md | Changed validation commands or constraints |
| `ralphio-generate-spec` | PROMPT_spec.md | Changed domain vocabulary or spec format |
| `ralphio-generate-plan` | PROMPT_plan.md | Changed source paths or plan format |
| `ralphio-generate-build` | PROMPT_build.md | Changed validation commands or commit style |
| `ralphio-generate-loop` | loop.sh | Changed CLI tool or model preferences |

---

The core insight: Ralph loops are simple — study, plan, build, validate, commit, repeat. The complexity is in getting the prompts right for *your specific project*. This skill handles that complexity so you can focus on building.
