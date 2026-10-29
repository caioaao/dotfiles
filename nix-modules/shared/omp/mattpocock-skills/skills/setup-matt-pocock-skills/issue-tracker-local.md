# Issue tracker: Local Markdown

Issues and specs live as markdown files in this repository's `.scratch/`. This directory is the owning write target; a link to another repository is not permission to modify it. Publishing here means a local file write, not a commit, push, or hosted publication.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of ordinary issue files (see `triage-labels.md` for the role strings); wayfinding files reserve `Status:` for their lifecycle and use `Triage:` for any triage role
- Comments and conversation history append to the bottom of the file under a `## Comments` heading; preserve earlier entries
- A `Labels:` line stores labels as literal strings, including configured triage overrides where used and the canonical `wayfinder:` labels below

## When a skill says "publish to the issue tracker"

Create the spec at `.scratch/<feature-slug>/spec.md` or an implementation ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, as appropriate. Create the directory if needed and choose an unused number; preserve existing files.

## When a skill says "fetch the relevant ticket"

Read the complete referenced file, including its body, metadata, and appended conversation. Resolve a bare issue number only within the named feature/effort; ask for missing scope rather than picking the same number from another directory.

## Parentage and blockers

Local markdown has no native edges. Record `Part of: <repo-relative source path>` in each implementation ticket and maintain an ordered list of child links in the source spec/map. Parentage records membership only: a ticket is not blocked by its parent.

Record prerequisites separately as `Blocked by: <repo-relative ticket path>, <repo-relative ticket path>`, or `Blocked by: none`. Use real existing paths, never predicted future filenames. A prerequisite is satisfied only when its file explicitly records completion (`Status: resolved` for wayfinding tickets, or the configured completed state for other tickets). Fetch every blocker's current state before claiming; missing files, unclear states, and cycles require correction rather than assumed readiness.

For a non-wayfinding closure, append the durable resolution under `## Comments` before saving its completed status. Preserve the resolution if a later status/map update fails, and report the remaining step.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md`, with `Labels: wayfinder:map`, Notes / Decisions-so-far / Fog sections, and an ordered `## Tickets` list of links to actual child files. Discover maps only by the exact `wayfinder:map` label, not arbitrary scratch files.
- **Child**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body, `Part of: .scratch/<effort>/map.md`, `Status: open`, `Assignee: none`, `Blocked by: none` (or real prerequisite paths), and exactly one canonical type label in `Labels:`: `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`. The label is the dispatch source of truth; omit a redundant `Type:` field.
- **Create / link**: write the full child file first, then append its real path to the map's Tickets list. Add prerequisite paths only after those files exist. Preserve unrelated metadata and map text.
- **Frontier**: read this map's ordered Tickets list and each linked child's full contents. Keep only children belonging to this map, with exactly one recognized type label, `Status: open`, `Assignee: none`, and all blockers `resolved`. First eligible child in map order wins. Missing/multiple type labels, unknown membership, or unclear blocker state require correction; other scratch tickets are out of scope.
- **Claim**: re-read eligibility, then save `Assignee: <driving-dev/session>` and `Status: claimed` before any work, as the session's first write. Re-read to confirm the claim and stop if ownership changed.
- **Resolve**: append the durable answer under `## Answer` and save it **before** saving `Status: resolved`. Then append a decision gist + child-file link to the map's Decisions-so-far and record newly surfaced tickets/links. Re-read the ticket and map before reporting completion. An unanswered question, failed save, or unfinished map update is not a completed wayfinder ticket.
