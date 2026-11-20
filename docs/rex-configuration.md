# Rex setup and operation

## macOS client

[`nix-modules/darwin/rex.nix`](../nix-modules/darwin/rex.nix) pins the
vendor-signed app and its matching server and CLI. Update the version/build and
DMG hash there; don't accept in-app updates for the Nix-managed copy.

Quit Rex before `sudo darwin-rebuild switch --flake .#darwin` so cached
preferences cannot overwrite the activation import. Launch
`/Applications/Nix Apps/Rex Beta.app` afterward. If replacing a manual install,
move the old copy out of `/Applications` and update Dock and login-item
references to avoid two apps with the same bundle ID.

[`rex.plist`](../nix-modules/darwin/rex.plist) sets native client preferences
(font, theme, and tab layout); `init.lua` configures the server and has no
client context at load time. The plist also enables **Remote Control**
(Rex → Settings → Server → Client Info). This lets other Rex clients control
the app and is required for the worktree picker's callback to switch sessions.
With it off, the checkout and session can still be created without being shown.
To disable it persistently, change the tracked plist before rebuilding.

## Linux server

[`nix-modules/nixos/rex.nix`](../nix-modules/nixos/rex.nix) runs a personal
Rex server as `caio`. Lingering keeps the user service available after logout.
Local and SSH clients share `$XDG_RUNTIME_DIR/rex/server.sock`; there is no
TCP listener or manual port forward. The Linux snapshot pin supplies
`rex __internal dial-stdio` for native `ssh://` hosts.

Deploy and restart the user service:

```sh
sudo nixos-rebuild switch --flake .#nixos
systemctl --user daemon-reload
systemctl --user restart rex
rex server status
```

The status should report the Unix socket in `$XDG_RUNTIME_DIR/rex`. On the Mac,
check `ssh nixos true`, then add `ssh://caio@nixos` as a host in Rex. This uses
the Mac's existing SSH alias and keys; `rex` must be on the remote non-interactive
PATH.

## Server configuration

Deploy the Nix packages and run `just stow rex` on each server host. Don't use
`--adopt`: it can copy a generated `init.lua` over the tracked file.
Run `rex config check` and `rex config reload` locally on each server; remote
reload is refused.

[`init.lua`](../stow-modules/rex/.config/rex/init.lua) owns the bindings.
The [Rex packages](../nix-modules/shared/rex) supply the picker modules.
Keep [`99-rex.sh`](../stow-modules/rex/.config/zsh/zshenv.d/99-rex.sh) in
`zshenv.d`: non-interactive picker commands need `REX_BIN_DIR` first on `PATH`
to use the active server's matching CLI. The globally installed CLI is not a
substitute.

## Pickers

Press Ctrl+Q, then the second key:

| Key | Action |
| --- | --- |
| `u` | Pick URLs from the focused terminal and its scrollback. Tab selects multiple entries. |
| `g` | Open or create a branch worktree. Alt+Enter uses the typed branch name instead of the fuzzy match. |
| Shift+G | Check out a GitHub PR by number or URL. Authenticate `gh` on the server host. |
| `d` | Remove a non-main, branch-associated worktree. |
| `w` / Shift+W | Switch to or create a native Rex session. |

Esc cancels the fzf pickers. The URL picker opens links **on the server host**
with `open` or `xdg-open`; it doesn't require client Remote Control.

Worktrunk handles checkout creation, reuse, and project hooks. The branch
picker starts new branches at the caller's HEAD. Opening a branch or PR
worktree creates or reuses a Rex session without changing the caller's shell.
Review hook commands before approving them.

**Save work before removing a checkout.** Successful removal can destroy its
managed session, killing processes and losing unsaved buffers. Main is excluded
and no force flag is passed, but a clean, unmerged checkout can still be removed.
A failed Worktrunk removal leaves the session intact.

The worktree picker maps canonical checkout paths to native session IDs in
`${XDG_STATE_HOME:-$HOME/.local/state}/rex/worktrunk/<server.instance_id>/sessions.json`.
Labels are for display, not ownership. Keep the registry across config reloads;
losing it can create duplicate sessions. If a picker was interrupted, remove
its `<server.instance_id>.lock` directory only after confirming no action is
running. Don't delete the registry as routine recovery.
