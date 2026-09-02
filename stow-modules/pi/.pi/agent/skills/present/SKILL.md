---
name: present
description: Turn source material (files, or something discussed in the session) into a self-contained, offline HTML presentation and open it in the browser. Use when asked to present, visualize, or make a shareable one-pager from existing material.
---

# Present

Turn source material into an offline HTML page that serves its reader better than the sources do.

Two roles share this file. The **orchestrator** is whoever the caller invoked: it resolves the sources and hands off, keeping the heavy work out of its context. The **executor** reads the sources and builds the page. If you have no `subagent` tool, play both roles in order.

## Orchestrator

### Resolve the sources

The sources are whatever the caller wants presented - your judgment. One file or several, a doc the conversation centers on, or material that exists only in the session (a concept discussed, findings, a design), in any mix. Anything else the caller said is steering: a form ("slides"), an audience, an outline, an emphasis. Ask only if genuinely unclear, then stop.

Resolve files to absolute paths. Material that lives only in the conversation is invisible to the executor: inline it in the task, faithfully and complete. Don't trim to save space; subagent tasks handle large payloads fine. When several sources go in, say how they relate if the caller did; otherwise leave that to the executor.

### Hand off

Spawn one subagent with a task shaped like:

> You are the executor for the `present` skill. Read `<absolute path you loaded this file from; your skill listing has it>` and follow its Executor section. Do not delegate. Sources: `<absolute paths, and/or the material itself, inlined>`. Working directory: `<cwd>`. Caller steering: `<steering, or "none">`.

Relay the executor's report to the user verbatim.

## Executor

### Intent

Present this material more clearly and engagingly than the sources do, so whoever opens the file gets what they came for. Read every source end-to-end. The material could be anything; don't pattern-match on its label.

Two questions decide the design. Settle both before writing any markup.

**What shape is the material?** Content has a shape, and the shape dictates what a good page looks like. Recognize it instead of compressing everything to one takeaway:

- *A point* - one concept, one finding. Lead with it; one visual anchor.
- *A map* - parts and their relations. Overview first, then each part; one diagram with a consistent legend; navigation that works.
- *A ladder* - ideas that build on each other. Keep the order; recap each rung before the next; show progress.
- *A fork* - alternatives. Lay out the trade-off space (matrix, side by side), then the recommendation.
- *A timeline* - ordered events or phases. Timeline, swimlanes, phase markers.
- *A delta* - before and after. Side by side; highlight only what changed.
- *A list* - independent findings, audit items, triage. Group by theme; make severity visible; each item stands alone.
- *Numbers* - benchmarks, metrics. Hand-built SVG charts; keep the data inspectable.
- *A reference* - cheat sheet, API surface, glossary. Dense, scannable, indexed; no takeaway needed.
- *An argument* - RFC, proposal. Problem, proposal, evidence, ask; the spine stays intact.
- *A synthesis* - several sources into one view. Mark provenance; surface where sources agree, contradict, or leave gaps.

Shapes nest. A design doc is often an argument whose evidence is a fork and whose context is a map; a tangle of concepts is usually a map whose nodes are each a ladder. Pick the outer shape, then a shape per section. For composite material, write the outline first; the structure is the hard part.

**How will the reader use it?** Skim for the answer, study in order, navigate a territory, look something up, or present it aloud. Form follows use: a skimmer gets the bottom line first and short chunks; a studier gets sequence and recaps; a navigator gets an overview and a table of contents; a looker-upper gets density and an index; a presenter gets slides. Absent steering, assume a read-on-screen page in whatever mode the shape implies.

With those settled, judge:
- What deserves emphasis, what collapses to a glance, what gets cut?
- Where does a visual land the point better than prose? Build it only when it earns its place. Interaction (a state machine to click through, a parameter to tweak) only when doing beats seeing.

Design for a reader whose attention wanders: short self-contained chunks, strong visual anchors so the eye lands on the load-bearing bits without hunting. Distinctive is welcome; decorative is not.

Reorder, group, summarize, and visualize freely. Stay faithful to the sources' meaning and invent no facts. The test: within a minute, a reader who never saw the sources knows what this is and where to go. For a point that is the takeaway itself; for a map, the overview; for a ladder, the path ahead; for a reference, the index.

### Delivery contract

Hard rules:
- Write under `${XDG_CACHE_HOME:-$HOME/.cache}/agent-context/present/` (`mkdir -p` it first), named `<slug>.<ext>`. Slug from the file name for a single file; from the theme for several files or session material. This is an ephemeral cache outside any repo: wipeable, never committed, never hand-edited. When the sources change, re-run this skill.
- The file's first line (after any doctype) is one comment naming every source: `<!-- present source: /abs/path -->`, files as absolute paths, session material as `session - <short label>`, several separated by `; `. Before writing, look for an existing file at the target path. Absent: you are creating. Present with the same marker: you are refreshing in place. Present with a different marker: suffix the slug and say so in the report.

Default:
- One self-contained, offline HTML file, `<slug>.html`. Opens via `file://` with no network dependencies: no CDN, no remote scripts, styles, fonts, or images. Inline everything; prefer system font stacks and hand-built SVG/CSS over any asset. Slides and interactive pages still fit in one file.

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
- one line on the shape and reader mode you chose and why
