---
name: skepsis
description: Use for Skepsis browser-based diff review, handing changes to a human for local review, or addressing Skepsis <review> comments in source files.
---

# Skepsis

[Skepsis](https://github.com/oxidecomputer/skepsis) serves a local diff UI. The human reviews in the browser; omp addresses the feedback written into source files. The CLI is installed through the shared Nix configuration.

## Open a review

1. Resolve the repository root and the requested review scope. Run from that root so diff paths and inline comment paths agree. Skepsis detects jj first, then git; use `--git` when the caller wants git in a colocated repository.
2. Choose the diff deliberately:

   | Scope | Git | jj |
   | --- | --- | --- |
   | Branch plus working copy against trunk's fork point | `skepsis` | `skepsis` |
   | Working-copy changes only | `skepsis --git -r HEAD` | `skepsis -r @` |
   | Named base through working copy | `skepsis --git -f main` | `skepsis -f main -t @` |
   | Two committed revisions | `skepsis --git -f REV_A -t REV_B` | `skepsis -f REV_A -t REV_B` |

   Replace example refs with the repository's refs. Git `-f BASE` includes the working tree; adding `-t REV` makes it commit-to-commit. Git `-r A..B` also excludes the working tree. Inline comments need a diff ending at the working copy. Git diff omits untracked files: report any review-scope gaps and preserve the index rather than staging files just to display them. Append `-- path/to/file` to limit paths when requested.
3. Start the command as a managed long-lived background service, with a unique name and readiness matching `skepsis on `. Keep the default loopback host and automatically assigned port. Skepsis opens the default browser; add `--no-open` when the caller requests a link only or no GUI is available. Leave polling enabled so the human can refresh after edits.
4. Capture the actual readiness line, `skepsis on <url> (<diff command>)`. Give the human the **complete URL including `#token=…`**, the selected scope, and the service handle. Treat the token as a local access secret; keep it out of repository files. Leave the service running for review and wait for the human's feedback instead of changing files while they annotate.

## Address review comments

When asked to address feedback, find every Skepsis review block in the requested source paths and read its surrounding code. A block follows the line it annotates:

```ts
const value = parse(input)
// <review>
// What happens for invalid input?
// </review>
```

`<review covers="N lines above">` covers the N source lines immediately before its opening tag. Comment delimiters vary by language. Comments can shift line numbers; use current source context, not remembered positions. Unknown file types may contain bare tags, which can make the file temporarily invalid. Skepsis refuses inline comments on symlinks.

For each block, resolve the underlying concern, verify the changed behavior, then remove that addressed block. Preserve unrelated edits and unresolved feedback. If a concern needs a decision or is not actionable, report it explicitly and leave its block in place. Completion means every discovered block is either addressed and removed or reported as unresolved. Tell the human to refresh the UI; polling offers a Refresh action rather than replacing their displayed diff automatically.

## Sending instead of editing files

Use `--send <command>` only when the caller requests an external feedback destination and the command is known. Skepsis runs it with `sh -c` in the launch directory and supplies one JSON object on stdin; `.prompt` contains the complete human-readable feedback. This also works for removed lines and historical diffs where inline comments cannot be written. There is no assumed omp queue or messaging socket: the default omp workflow is inline review blocks followed by the human asking to address them. Keep sending on loopback and treat comment text as data, not shell code.

## Finish

Keep the server alive across review rounds. Stop only the service started for this review when the human finishes or requests shutdown. Report the addressed concerns, verification, and any remaining feedback; keep review markers out of commits once resolved.
