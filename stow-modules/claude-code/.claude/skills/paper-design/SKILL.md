---
name: paper-design
description: Create or refine UI designs on the Paper canvas, following the project's visual identity.
argument-hint: "[what to design]"
---

# Design

Use the Paper MCP tools to create or refine UI designs on the user's canvas, following the project's visual identity.

## Before Starting

Read these files before any design work:

1. Read `AGENTS.md` — project identity, stack, UI framework details, docs locations.
2. Look for a design system spec. If one exists, treat it as the canonical reference for colors, typography, spacing, and component patterns.
3. Skim filenames for awareness of existing features and pages.
4. If the task involves a specific feature, read its spec too.

## Process

### 1. Understand the Canvas

1. `get_basic_info` — file structure, artboards, loaded fonts.
2. `get_selection` — what the user is focused on.
3. If existing artboards are relevant, `get_tree_summary` + `get_screenshot` to understand current state.

### 2. Clarify Intent

If the request is ambiguous, use `AskUserQuestion`:

- **header:** "Scope" / **question:** "What are we designing?" — options relevant to the request
- **header:** "Device" / **question:** "What viewport?" — "Desktop (1440px)", "Mobile (390px)", "Both"
- **header:** "Mode" / **question:** "Color mode preference?" — "Dark", "Light", "Both"

### 3. Design

1. Write a short design brief (palette, type, spacing, direction) aligned with the design system spec (if one exists).
2. `create_artboard`.
3. Build incrementally — one visual group per `write_html` call.
4. Use `duplicate_nodes` + `update_styles` + `set_text_content` for repeated elements.
5. Screenshot after every 2-3 modifications.

### 4. Review

After each screenshot, check:

- **Spec compliance:** Correct colors, typography, component patterns per design system spec?
- **Spacing:** Follows the spacing scale? Tighter for related elements, generous for hero content?
- **Typography:** Correct font families and weights per spec? Proper hierarchy?
- **Contrast:** Text readable? Accent used deliberately?
- **Alignment:** Vertical lanes consistent across repeated rows?
- **Clipping:** Content cut off at edges?

Fix issues before moving on.

### 5. Link to Linear Ticket

If this design was created for a Linear ticket (provided via `$ARGUMENTS` or discussed with the user):

1. Call `finish_working_on_nodes` — this returns the URL of the created/modified artboard.
2. Attach the Paper URL to the ticket: `mcp__linear-server__create_attachment` with the ticket ID, the Paper URL as `url`, and a title like "Design — [artboard name]".

### 6. Finish

If not already called in step 5, call `finish_working_on_nodes` when done.

## Rules

### Follow the Design System Spec

Read the active design system spec (project-specific or global) and follow its tokens, colors, typography, and component patterns.

### Paper-Specific

- Inline styles only.
- `display: flex` for layout. No grid, no inline, no margins.
- No emojis as icons. Use SVGs or unicode markers from the design spec.
- Use realistic placeholder content relevant to the product domain (infer from AGENTS.md).

### Incremental Building

- Each `write_html` = ONE visual group (header, row, button group, card shell).
- A card with header + 4 rows + footer = 6+ calls, not one.

## Adapting Existing Pages

When redesigning an existing page:

1. Read current templates in the project's web/UI layer (check AGENTS.md for the source layout).
2. Read relevant CSS/styling configuration.
3. Understand current layout before proposing changes.

$ARGUMENTS
