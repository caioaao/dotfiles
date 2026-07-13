# pi-observer

A glanceable monitor for active [pi](https://github.com/earendil-works/pi)
sessions: one pane that answers *"what is that agent up to, and does it
need me?"* without reading transcripts.

Two programs joined by a frozen data-dir contract
([CONTRACT.md](./CONTRACT.md)):

- `extension/` - TypeScript pi extension (runs inside pi's process).
  Publishes a small liveness doc per session. Write-only,
  dependency-free, self-disables on repeated failure.
- `piobs/` - Go CLI/TUI (Bubble Tea). Reads the registry, parses pi's
  session JSONL read-only, narrates activity via a small LLM, renders
  it, and hops to tmux panes.

## Philosophy

**Narrate the task, not the conversation.** A transcript tells you what
was *said*; an observer needs to know how the *task* evolved. The
distiller is a narrator: it describes the session the way a colleague
would after skimming it - "it abandoned the trigger approach after
hitting a deadlock, and is now writing the migration".

**Narration needs revision, so the primary artifact is rewritten, not
appended.** "That experiment was a dead end" can only be written *after*
the dead end. An append-only log can never revise its own telling. The
distiller therefore maintains a **living brief** (`SessionDoc`) that it
rewrites in full on every pass. The append-only feed still exists
underneath - as the crash-safe substrate, the beat ticker, and the
rebuild source - but it is secondary.

**Fixed skeleton, adaptive organs.** Sessions differ in shape:
implementation has a plan, debugging has hypotheses, research has
findings. The model chooses *which sections exist*; it never chooses
the layout. NOW is always first, WAITING always second and loud, SO FAR
always last. Spatial stability is what makes a pane glanceable - a
dashboard that reorganizes itself must be read instead of glanced at.

**Write to fit, never truncate to fit.** The model gets sentence
budgets ("1-2 sentences", "3-8 sentences") and writes complete
sentences. Hard truncation exists only as a corruption backstop; a
mid-sentence ellipsis on screen is a bug, not a policy.

**Attention follows need.** Idle sessions wait on the human, so they
sort first and get the loud color. Working sessions need nothing and
stay calm. Suppression is a feature: an empty beat list is the common,
correct distiller output.

**Narration is opt-in for the past.** Auto-distill covers the living
present: the selected session, small deltas. Rotten sessions (exited
for 5+ minutes) and oversized backlogs (> 200 KiB behind) are
archaeology - the pane says so ("auto-distill off - press g") instead
of silently burning tokens narrating history nobody asked to read.
Failed distills back off for 30s rather than retrying every tick.

**Everything is reversible.** Pi's session files are the read-only
source of truth. Feed, state, and doc can all be rebuilt from scratch
(`piobs redistill`); the observer never writes into pi's data.

## Implementation

### Extension (write side)

`extension/index.ts` + `extension/lib/registry.ts`. Subscribes to pi's
lifecycle events and atomically rewrites one registry doc per session
under `~/.local/share/pi-observer/sessions/` - pid, cwd, model, tmux
pane, working/idle state, a live "doing X" one-liner. It never reads;
it never touches feeds. On repeated write failure it disables itself
rather than degrade the host session.

### piobs (read side)

```
piobs                       TUI: session list + living brief + beats
piobs list                  print sessions to stdout
piobs distill <id-prefix>   one-shot catch-up distill (prints the doc)
piobs redistill <id-prefix> rebuild a session's feed + doc from scratch
```

Packages (`piobs/internal/`):

- `session` - the only package that touches pi's JSONL format. Parses
  incrementally from a byte offset into `ActivityItem`s (turns, prompts,
  markers). Mechanical classification lives here: skill injections
  collapse to `(loaded skill: X)`, final answers keep their first prose
  paragraph.
- `store` - the CLI side of the contract: registry read + pid-reuse-
  guarded liveness, parentage resolution (subagents are direct child
  processes; the list nests them under their parent), feed append/read,
  state/doc persistence, the crash-safe watermark, gc.
- `distill` - the narrator. Mechanical items (prompts, done, errors,
  compaction, branch switches) bypass the LLM. Turns are chunked and
  sent with the previous doc + feed tail; the model returns the
  rewritten doc plus 0..n beat lines. Unparseable output keeps the old
  doc and emits nothing - a redistill can always retry.
- `tui` - Bubble Tea app. `docview` renders the brief with the fixed
  skeleton; `feedview` renders beats with turn folding (finished turns
  collapse to prompt + outcome) and zoom levels; the session list
  (`delegate`) sorts working-first and titles items by `doc.title` - a
  distilled, stable task name (session name wins when set; no prompt
  fallback, a context-free prompt is worse than a placeholder).

TUI keys: `j/k` switch session, `enter` hops to the tmux pane, `1-4`
zoom (brief / brief+beats / +details / raw), `x` unfolds history, `s`
shows subagent sessions (hidden by default), `g`/`r` distill/redistill, `f` pins the view
to the top (where NOW lives).

### Distillation pipeline

```
pi session JSONL ──parse──> ActivityItems ──┬─ mechanical ──> feed entries
                                            └─ turn chunks ──> LLM ──> beat lines
                                                               │
                                previous doc ──────────────────┴──> rewritten doc
```

Idempotency: every feed entry carries `upTo` (session-file byte
offset); `state.json` caches the offset plus the doc. The watermark
rule (see CONTRACT.md) makes distillation crash-safe without ever
re-feeding quiet regions or duplicating lines.

## Spec

The full wire format lives in [CONTRACT.md](./CONTRACT.md): registry
doc schema, feed entry kinds, `SessionDoc` (now / waiting / sections /
story, budgets, the open-enum rules), the watermark rule, and gc
ownership. Any schema change edits both implementations and that file.

Distiller config (optional): `~/.config/pi-observer/config.json` with
`provider` (only `anthropic`; needs `ANTHROPIC_API_KEY`), `modelId`
(default `claude-haiku-4-5`), `maxTokens` (default 2048). Doc quality
scales with the model; bump `modelId` if the narration reads thin.

## Packaging

The extension is a pi package (linked under
`share/pi/packages/pi-observer`, referenced by pi's settings.json);
piobs is a normal system binary (`buildGoModule`), wired into
`environment.systemPackages` directly.

## Development

Go module lives in `piobs/`:

```
nix shell nixpkgs#go
go test ./...
```

Known gaps: no push notifications on idle/error transitions yet.
Sessions registered before the `ppid` field existed (or by an older
extension still loaded in a running pi) show as top-level until that
pi restarts.
