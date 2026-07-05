# pi-observer data-dir contract

Frozen interface between the registry extension (TypeScript, runs inside
pi) and the piobs CLI (Go). Both implementations cite this document; any
schema change requires editing both sides and this file.

## Paths

```
~/.local/share/pi-observer/
  sessions/<sessionId>.json       registry doc     (extension-owned)
  feed/<sessionId>.jsonl          distilled feed   (CLI-owned, append-only)
  feed/<sessionId>.state.json     distiller state  (CLI-owned)

~/.config/pi-observer/config.json distiller config (user-owned, CLI-read)
```

Pi's own session JSONL files (`~/.pi/agent/sessions/...`, referenced by
`sessionFile`) are the read-only content source. Neither side ever writes
them. Distillation is reversible: the feed can always be rebuilt from
scratch from the session file.

## Ownership

- The **extension** writes only `sessions/`. Atomic rewrite per update:
  write `<path>.tmp`, then rename over `<path>`.
- The **CLI** writes only `feed/`. Feed files are append-only JSONL;
  state files are atomic rewrites (tmp + rename).
- **gc exception**: the CLI additionally holds delete rights over
  `sessions/` docs - it removes the registry doc *and* the feed/state
  files for sessions whose effective state is `exited` and whose
  `updatedAt` is older than 14 days. This is the only cross-ownership
  write and it is delete-only.

Both sides create `sessions/` and `feed/` (mkdir -p) before writing.

## RegistryDoc (`sessions/<sessionId>.json`)

One JSON object. `schemaVersion` is currently **1**; readers MUST reject
(skip) docs with an unknown `schemaVersion` instead of guessing.

| field             | type                     | notes                                        |
| ----------------- | ------------------------ | -------------------------------------------- |
| `schemaVersion`   | number                   | `1`                                          |
| `sessionId`       | string                   | pi session UUID                              |
| `pid`             | number                   | pi process pid                               |
| `pidStartedAt`    | number                   | process start time, epoch ms (may be float)  |
| `cwd`             | string                   |                                              |
| `sessionFile`     | string \| null           | pi JSONL path; null for in-memory sessions   |
| `sessionName`     | string \| null           |                                              |
| `model`           | string \| null           | `provider/modelId`                           |
| `tmux`            | `{pane: string}` \| null | tmux pane id, e.g. `%49`                     |
| `state`           | string                   | `working` \| `idle` \| `exited`              |
| `currentActivity` | string \| null           | live "doing X" one-liner while a tool runs   |
| `startedAt`       | string                   | ISO 8601                                     |
| `updatedAt`       | string                   | ISO 8601; sort key and gc age source         |
| `lastPrompt`      | string \| null           | truncated to 200 chars by the writer         |

### Liveness (reader-side)

Registry `state` is a claim, not a fact - a crashed pi never writes
`exited`. Readers derive an *effective state*:

- if `state != exited` and the process is not alive, effective state is
  `exited`; otherwise effective state = `state`.
- Alive check is pid-reuse-guarded: `kill -0 pid` AND process start time
  (from `ps -o etime= -p <pid>`, format `[[dd-]hh:]mm:ss`) within 30s of
  `pidStartedAt`. If `etime` is unparseable, assume alive. `kill -0`
  alone would make crashed sessions immortal once the pid is recycled.

## FeedEntry (`feed/<sessionId>.jsonl`)

One JSON object per line, append-only, chronological.

| field    | type   | notes                                                        |
| -------- | ------ | ------------------------------------------------------------ |
| `t`      | string | ISO 8601                                                     |
| `kind`   | string | `phase` \| `insight` \| `note` \| `backtrack` \| `done` \| `error` \| `prompt` |
| `text`   | string | one line, <= 300 chars (done: <= 500)                        |
| `detail` | string | optional, <= 600 chars                                       |
| `upTo`   | number | session-file **byte** offset this line covers                |

Readers MUST tolerate a partially-written (non-newline-terminated or
corrupt) final line by skipping it. Unknown `kind` values render as
`note`.

## DistillerState (`feed/<sessionId>.state.json`)

| field   | type   | notes                                           |
| ------- | ------ | ----------------------------------------------- |
| `upTo`  | number | byte offset distilled so far                    |
| `state` | string | distiller's rolling summary, <= 500 chars       |

## Watermark rule (crash-safe, exact)

`state.json` legitimately runs AHEAD of the feed: chunks that emit no
feed lines advance only `state.json`. A watermark derived purely from
the feed re-feeds quiet regions to the LLM on every pass - silent
corruption. The exact rule:

```
fromFeed  = last feed entry's upTo, or 0 if feed empty/absent
watermark = state.json            if state.json exists AND state.upTo >= fromFeed
          = {upTo: fromFeed,
             state: state.json.state or ""}   otherwise
```

The feed is the source of truth only when it is ahead of (or state.json
is missing/behind) the cached state - that covers the crash window
between feed-append and state-write without duplicating lines, while
keeping quiet-region progress.

Write ordering during distillation: append feed entries first, then
write state.json. `upTo` values written to the feed MUST point at the
end of a complete (newline-terminated) session-file line, so a partial
tail is never skipped.

## Config (`~/.config/pi-observer/config.json`)

Optional; missing file or fields fall back to defaults.

| field       | type   | default            |
| ----------- | ------ | ------------------ |
| `provider`  | string | `anthropic`        |
| `modelId`   | string | `claude-haiku-4-5` |
| `maxTokens` | number | `1024`             |

## Implementations

- extension: `lib/registry.ts` (write side of `sessions/`)
- CLI: `piobs/internal/store` (everything else)
