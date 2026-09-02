---
name: present
description: Turn source material (a file, or something discussed in the session) into a self-contained, offline HTML presentation and open it in the browser. Use when asked to present, visualize, or make a shareable one-pager from existing material.
---

# Present

Turn source material into an offline HTML page that gets its point across better than the source does.

Two roles share this file. The **orchestrator** is whoever the caller invoked: it resolves the source and hands off, keeping the heavy work out of its context. The **executor** reads the source and builds the page. If you have no Task tool, play both roles in order.

## Orchestrator

### Resolve the source

The source is whatever the caller wants presented - your judgment. It may be a file they named, a doc the conversation centers on, or material that exists only in the session (a concept discussed, findings, a design). Anything else the caller said is steering. Ask only if genuinely unclear, then stop.

If the source is a file, resolve it to an absolute path. If it lives only in the conversation, the executor cannot see it: inline it in the task, faithfully and complete. Don't trim to save space; sub-agent tasks handle large payloads fine.

### Hand off

Spawn one sub-agent (Task tool) with a task shaped like:

> You are the executor for the `present` skill. Read `<absolute path you loaded this file from; your skill listing has it>` and follow its Executor section. Do not delegate. Source: `<absolute path, or the material itself, inlined>`. Working directory: `<cwd>`. Caller steering: `<steering, or "none">`.

Relay the executor's report to the user verbatim.

## Executor

### Intent

Present this material more engagingly and clearly than the source, so whoever opens the file gets the point. Read the source end-to-end, then judge what the reader must walk away with and the form that delivers it. The source could be anything; don't pattern-match on its label.

Questions to settle for yourself:
- What is the one thing the reader must get, and the fastest path to it?
- What deserves emphasis, what collapses to a glance, what gets cut?
- Where does a visual (a diagram, a comparison) land the point better than prose? Build it only when it earns its place.
- Absent caller steering, assume a read-on-screen scrolling page.

Design for a reader whose attention wanders: bottom line first, short self-contained chunks, strong visual anchors so the eye lands on the load-bearing bits without hunting. Distinctive is welcome; decorative is not.

Reorder, group, summarize, and visualize freely. Stay faithful to the source's meaning and invent no facts. A reader who never saw the source should grasp the main point in under a minute.

### Delivery contract

Hard rules:
- Write under `${XDG_CACHE_HOME:-$HOME/.cache}/agent-context/present/` (`mkdir -p` it first), named `<slug>.<ext>` with the slug derived from the source. This is an ephemeral cache outside any repo: wipeable, never committed, never hand-edited. When the source changes, re-run this skill.
- The file's first line (after any doctype) is a comment naming the source: `<!-- present source: /abs/path -->`, or `<!-- present source: session - <short label> -->` for conversation-only material. Before writing, look for an existing file at the target path. Absent: you are creating. Present with the same source marker: you are refreshing in place. Present with a different marker: suffix the slug and say so in the report.

Default:
- One self-contained, offline HTML file, `<slug>.html`. Opens via `file://` with no network dependencies: no CDN, no remote scripts, styles, fonts, or images. Inline everything; prefer system font stacks and hand-built SVG/CSS over any asset.

Precedence: hard rules hold. The default yields only to a strong reason (stated in your report) or explicit caller steering. Within what those leave open, the intent governs.

### Open it

After writing the file, open it in the default browser:

```bash
case "$(uname -s)" in
  Darwin) open "<absolute path>" ;;
  Linux)  xdg-open "<absolute path>" ;;
esac
```

Skip only if the caller said not to open, or the environment clearly has no GUI (SSH session, Linux without `DISPLAY`/`WAYLAND_DISPLAY`). Say so when you skip.

### Verify and report

Unless you deliberately departed from the default (and say why), prove the artifact stands alone:

```bash
grep -nE '(src|href|srcset|url\(|@import)[^>;]*(https?:)?//' "<absolute path>" | grep -v 'w3.org'
```

Empty output is the pass; it also covers protocol-relative URLs and web fonts. Claim the check only if you ran it.

Then report:
- created, refreshed, or suffixed (and why, if suffixed)
- the full absolute `file://` URL, copy-paste-ready
- whether it opened automatically
- the verification result
- one line on the angle you chose and why
