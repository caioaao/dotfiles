# pi-observer

Big-picture feed of active pi sessions. Two programs joined by a
data-dir contract ([CONTRACT.md](./CONTRACT.md)):

- `extension/` - TypeScript pi extension (runs inside pi's process).
  Publishes a small liveness doc per session to
  `~/.local/share/pi-observer/sessions/`. Write-only, dependency-free,
  self-disables on repeated failure.
- `piobs/` - Go CLI/TUI (Bubble Tea). Reads the registry, parses pi's
  session JSONL read-only, distills activity into a semantic feed via a
  small LLM (Anthropic; needs `ANTHROPIC_API_KEY`), renders it, and hops
  to tmux panes.

```
piobs                       TUI: session list + distilled feed
piobs list                  print sessions to stdout
piobs distill <id-prefix>   one-shot catch-up distill
piobs redistill <id-prefix> rebuild a session's feed from scratch
```

Distiller config (optional): `~/.config/pi-observer/config.json` with
`provider` (only `anthropic`), `modelId`, `maxTokens`.

Packaging: the extension is a pi package (linked under
`share/pi/packages/pi-observer`, referenced by pi's settings.json); piobs
is a normal system binary (`buildGoModule`), wired into
`environment.systemPackages` directly.

Development (Go module lives in `piobs/`):

```
nix shell nixpkgs#go
go test ./...
```
