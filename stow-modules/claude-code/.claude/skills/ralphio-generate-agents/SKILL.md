---
name: ralphio-generate-agents
description: Generate AGENTS.md for a project - a concise operational guide (~40-60 lines) that steers AI agent behavior toward correct patterns. First step in Ralph loop bootstrap.
bootstrap_order: 1
optional_inputs: []
---

# Generate AGENTS.md

## What This Skill Does

Generates `AGENTS.md` — a concise operational guide (~40-60 lines) loaded into every AI agent session. It's the "heart of the loop" — it steers agent behavior toward correct patterns and away from common mistakes.

AGENTS.md is NOT documentation, NOT a README, NOT a changelog.

## Bootstrap Context

This is **step 1 of 5** in the ralphio bootstrap sequence:

1. **generate-agents → AGENTS.md** ← you are here
2. generate-spec → PROMPT_spec.md
3. generate-plan → PROMPT_plan.md
4. generate-build → PROMPT_build.md
5. generate-loop → loop.sh

This skill has no dependencies. Run it first.

## Before Generating

Study the target project thoroughly before writing anything:

- README and project description — domain context and project identity
- Directory structure — language, framework, existing patterns
- Build/test/lint scripts — validation commands
- Config files — constraints and conventions
- Existing AGENTS.md (if present) — preserve valuable operational notes

## What to Include (Steering Information)

Only include things the agent cannot discover by reading the code:

### 1. One-Line Project Identity
What it is and where it's deployed. This anchors the agent's mental model.

Example: "Zola static blog deployed to https://example.com"

### 2. "Study First" Command
The single most important line. Forces the agent to search before assuming.

Use exact phrasing: **"Study existing [code/posts/tests/etc]. Don't assume not implemented — search first."**

This specific language activates careful, investigative behavior.

### 3. Source-of-Truth Pointers
If specs, design systems, or architectural decision records exist, point to them explicitly and state they are authoritative.

Example: "Study specs/DESIGN.md before any UI work. It is the source of truth."

### 4. Validation Commands (Backpressure)
The exact commands to build, test, typecheck, lint. These are the gates that reject bad work. Keep them copy-pasteable:

```
- Build: `npm run build`
- Test: `npm test`
- Lint: `npm run lint`
```

### 5. Constraints the Code Doesn't Express
Things that would cause silent correctness errors if violated:

- Token/variable systems ("use semantic tokens from X, never hardcode")
- Architectural boundaries ("no CSS custom properties yet, Sass variables only")
- Framework-specific gotchas ("Tera templating, not Jinja2")

### 6. Non-Obvious Patterns
Things that look wrong but are intentional. Without these, the agent will "fix" them:

- Inverted conventions ("title is larger than headline — intentional")
- Signature design elements ("paper texture background — do not remove")
- Unusual defaults ("20px base, not 16px")

### 7. Operational Notes Section
Start nearly empty with the instruction: **"Grows reactively. When you learn something new about running the project, add it here."**

This makes the file self-improving across sessions.

## What to Exclude (Discoverable Information)

Remove anything the agent can learn by reading files:

- File/directory listings (use Glob)
- Import chains and dependency graphs (read the code)
- Config file contents (read the config)
- CLI command explanations (the agent knows standard tools)
- Setup instructions (read package.json, flake.nix, Dockerfile, etc.)
- Code examples and API signatures (read the source)
- Content/naming conventions demonstrated by existing files

**The test:** For each line, ask "would the agent produce wrong output without this?" If no, delete it.

## Language That Activates Good Behavior

| Use this | Not this | Why |
|---|---|---|
| "Study" | "Read" or "Look at" | Activates deeper analysis, not superficial scanning |
| "Don't assume not implemented — search first" | "Check if it exists" | Creates strong backpressure against hallucinated reimplementation |
| "Source of truth" | "Reference" or "Guide" | Establishes authority hierarchy — agent won't override it |
| "Non-negotiable" | "Important" or "Required" | Hard stop, not a suggestion |
| Exact commands: `npm test` | "Run the tests" | Eliminates guessing, enables copy-paste execution |
| "Grows reactively" | "Add notes here" | Signals incremental, observation-driven evolution |

## Structure Template

```markdown
# AGENTS.md

[One-line project identity and deployment target.]

## Before Making Changes

[Study-first command. Source-of-truth pointers.]

## Validation

[Exact build/test/lint commands.]

## Constraints

[Things the code doesn't express that cause silent errors if violated.]

## Non-Obvious Patterns

[Things that look wrong but are intentional.]

## [Domain-Specific Section]

[Only if the project has a content domain with semantic rules — e.g., blog post format, API versioning scheme.]

## Operational Notes

_Grows reactively. When you learn something new about running the project, add it here._

[Seed with 2-3 things you already know are non-obvious.]
```

## Anti-Patterns

- **Bloat**: A long AGENTS.md pollutes every future session's context window. Brevity is not a nice-to-have — it directly impacts agent intelligence. The "smart zone" of context is ~40-60% of the window.

- **Prescribing the obvious**: Don't tell the agent how to use git, how to run standard CLI tools, or what a directory structure means.

- **Static best practices**: Don't front-load generic rules. Start minimal, observe failures, add signs reactively. "Tune it like a guitar."

- **Duplicating docs**: If it's in a README, config file, or the code itself, it doesn't belong here.

## Design Principles (ralphio system)

- **Generate-then-own**: This skill generates a tailored artifact. The user owns it from that moment. No updates, patches, or versioning.

- **Self-contained output**: AGENTS.md contains everything an agent needs. No imports, no references to external files.

- **Study before generating**: Discover the project thoroughly before producing output. Discovery over assumption.

- **Behavioral outcomes over implementation**: Describe what the artifact must accomplish, not how to structure it internally.

---

The core insight: prompts are signposts, not manuals. You're not teaching the agent — you're steering latent knowledge it already has. Every line should either prevent a specific mistake or activate a specific domain of expertise. Everything else is noise that degrades performance.
