# Tmux Agent Protocol

A coding agent running inside a tmux pane publishes its identity and lifecycle
state as pane-scoped tmux user options. Any tmux-side consumer (pane pickers,
status bars) can then discover and label agent panes without knowing which
agent is running. The agent owns the data; consumers own the presentation.

The protocol is intentionally tiny: three string options, no daemon, no IPC.
An agent publishes by shelling out to tmux, so any agent that can run a command
can participate (`pi`, `omp`, `claude`, `codex`, ...).

## Options

All options are pane-scoped and set with `tmux set-option -p -t "$TMUX_PANE"`.

| Option | Required | Meaning |
| --- | --- | --- |
| `@agent_name` | yes | Agent identity token, e.g. `pi`, `omp`, `claude`, `codex`. Its presence marks the pane as an agent pane. |
| `@agent_status` | yes | Lifecycle token for the current turn. See vocabulary below. |
| `@agent_session` | no | Display label for the agent's own session. Publishers should prefer a user-assigned session name and fall back to a stable session id. Opaque to consumers. |

Rendering, filtering, and previewing are entirely the consumer's concern. A
pane without `@agent_name` is not an agent pane and MUST be ignored by agent
tooling.

## Status vocabulary

| Token | Meaning |
| --- | --- |
| `idle` | Finished a turn; waiting for user input. |
| `working` | Executing a turn. |

The set is open: agents MAY publish other tokens (e.g. `blocked`, `error`).
Consumers MUST render unknown tokens verbatim rather than dropping them; how a
status is decorated is the consumer's choice.

## Publishing

```bash
tmux set-option -p -t "$TMUX_PANE" @agent_name   pi
tmux set-option -p -t "$TMUX_PANE" @agent_status working
tmux set-option -p -t "$TMUX_PANE" @agent_session fix-auth-bug
tmux refresh-client -S
```

Rules:

- `@agent_name` and `@agent_status` MUST be set before the pane is considered
  an agent pane.
- `@agent_session` MAY be omitted; consumers fall back to a placeholder.
- Values MUST be single-line and tab-free: they are interpolated into tmux
  format strings.
- On exit the agent MUST unset all three options
  (`tmux set-option -p -t "$TMUX_PANE" -u @agent_name`, ...) so the pane stops
  being advertised.
- Outside tmux (`$TMUX` unset) publishing is a no-op.

## Consumers

- **`tmux-agent-panes`** - lists every pane with `@agent_name` set, showing name, status,
  session, and location, and switches to the selection.

Nothing in the tmux config is agent-aware: window names are managed manually,
and agents never install global options.

## Reference publisher

`~/.pi/agent/extensions/tmux-agent.ts` implements the protocol for pi: it sets
the options on `session_start`, tracks `agent_start` / `agent_end` /
`session_info_changed`, and clears them on `session_shutdown`. Agents without
an extension host can publish from lifecycle hooks using the commands above.
