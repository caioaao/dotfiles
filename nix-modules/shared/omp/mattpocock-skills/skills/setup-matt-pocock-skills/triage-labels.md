# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding string from the **Label in our tracker** column. Existing configured overrides are authoritative; keep them on setup reruns unless the user explicitly changes them. Canonical role names are not extra labels to create when an override is chosen.

During confirmed hosted setup, inspect the explicit owning target in `issue-tracker.md`, reuse existing exact matches, and create only missing chosen strings using that tracker's supported label operation. Preserve existing label colors/descriptions. Read the labels back before declaring setup complete. Reading this mapping during normal work is not authorization to change tracker configuration.

For local markdown, record the chosen role string in the configured triage metadata; no hosted label creation is needed. Wayfinding lifecycle (`open` / `claimed` / `resolved`) is separate from triage roles.

The `wayfinder:` labels are a separate fixed vocabulary, not entries in this triage-role mapping: `wayfinder:map`, `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, and `wayfinder:task`. When that skill is installed, confirmed setup ensures these also exist (or records them in local `Labels:` metadata), even if `triage` is absent.
