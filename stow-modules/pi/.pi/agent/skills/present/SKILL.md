---
name: present
description: Turn source material (a doc, or something discussed in the session) into a self-contained, offline HTML presentation at .local/present/<slug>.html and open it in the browser. Use when asked to present, visualize, or make a shareable one-pager from existing material. Token-heavy - delegates itself to a subagent when one is available.
---

# Present

Turn a source doc into an offline HTML page that gets its point across better than the source does.

## Resolve the source

The source is whatever the caller wants presented - your judgment. It may be a file they named, a doc the conversation is centered on, or material that exists only in the session (a concept discussed, findings, a design). Anything else the caller said is steering. Ask only if genuinely unclear, then stop.

If the source is a file, resolve it to an absolute path. If the material lives only in the conversation, the subagent cannot see it - inline it in the task, faithfully and complete. Don't trim to save space; subagent tasks handle large payloads fine.

## Delegate first (context hygiene)

Reading the source end-to-end and authoring HTML burns a lot of context. If you have the `subagent` tool, do NOT do this inline. Instead:

1. Spawn a subagent with a task like:
   > Read `~/.pi/agent/skills/present/SKILL.md` and follow it exactly. Source: `<absolute path, or the material itself, inlined>`. Work from `<cwd>`. Extra steering: `<caller steering, if any>`.
2. Relay the subagent's report (created/refreshed, `file://` URL, chosen angle) to the user verbatim.

If you don't have the `subagent` tool (e.g. you *are* the subagent), follow the rest of this file yourself.

## Intent

**One intent, unchanging: present this material more engagingly and clearly than the source, optimizing for getting the point across to whoever opens the file.** This is the north star for *what to present and how to shape it*. The delivery contract below is a separate concern - see Precedence for how they interact.

Read the source end-to-end first. Then judge - yourself - what the reader must walk away with and the form that delivers it best. The source could be anything; don't pattern-match on its label or shape. Find the through-line, the parts that carry the weight, the parts that are noise.

Judgment to make (questions, not a checklist):
- What's the one thing the reader must get? What path gets them there fastest?
- What deserves emphasis, what collapses to a glance, what gets cut?
- Where does a visual (e.g. a diagram or a comparison) land the point better than prose? Build it only when it earns its place.
- Absent caller steering, assume a read-on-screen scrolling page; adjust if the material clearly wants otherwise.

Design for a reader whose attention wanders. Lead with the bottom line, not buildup. Keep chunks short and self-contained so losing focus mid-read costs nothing to re-enter. Give strong visual anchors - clear headings, highlights, whitespace - so the eye lands on the load-bearing bits without hunting, and make it obvious where the reader is and how much is left. Hold attention with purposeful contrast, not decoration.

You are re-presenting substance, not transcribing into slides. Reorder, group, summarize, and visualize freely - stay faithful to the source's meaning, invent no facts. Aim so a reader who never saw the source grasps the main point in under a minute.

## Delivery contract

- **Strong default: one self-contained, offline HTML file.** Opens via `file://` with zero external dependencies - no CDN, no remote scripts or styles, no web fonts, no remote images. Inline everything; prefer system font stacks and hand-built SVG/CSS over any asset.
- **Always: write to `.local/present/<slug>.html`** (`<slug>` derived from the source; `mkdir -p` the dir first). `.local/` is gitignored throwaway. Re-running on the same source refreshes that snapshot in place - report whether you created or refreshed it so the overwrite is never silent. Only when a *different* source would collide on the same slug, suffix the name instead and say so.
- **Always: the file is a generated snapshot.** Never hand-edit it; when the source changes, re-run this skill.

Precedence: the two `Always` rules hold no matter what. The `Strong default` yields only to a strong reason (stated in your final summary) or explicit caller steering. Within what these leave open, the intent governs content and form; lesser defaults fill the rest.

## Open it

After writing the file, open it in the default browser:

```bash
case "$(uname -s)" in
  Darwin) open "<absolute path>" ;;
  Linux)  xdg-open "<absolute path>" ;;
esac
```

Skip only if the caller said not to open, or the environment clearly has no GUI (e.g. SSH session, Linux without `DISPLAY`/`WAYLAND_DISPLAY`). Say so when you skip.

## Report

Before reporting done: unless you deliberately broke the strong default (and said why), verify the artifact stands alone - no `http(s)://` in any `src`, `href`, or `url(...)`, and no web fonts. Then report:
- created or refreshed
- the full absolute `file://` URL (copy-paste-ready, never a relative path)
- whether it was opened automatically
- one line on the angle you chose and why
