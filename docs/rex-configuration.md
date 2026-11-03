# Rex client configuration

Researched 2026-10-27 against official documentation and the installed Rex beta (macOS client build 1408; CLI commit `623b2d17d416b146ce9993a7cd2dfce964ea60e5`, API revision 7).

## Findings

- `init.lua` is server-side configuration for bindings, custom actions, hosts, and related automation. It is not documented as a declarative client appearance settings file. The server executes it at load time without a client context. [Configuration file](https://www.superlogical.com/rex/docs/customize/config)
- The complete documented Lua API has no declarative font-size or theme settings API. `rex.client.queue` requires a client and cannot run at configuration load time. It can run inside an invoked custom action or a separately executed script. [Lua API](https://www.superlogical.com/rex/docs/reference/lua)
- Custom actions are invoked through a binding, palette, or CLI; defining one does not apply it automatically on client launch. [Custom actions](https://www.superlogical.com/rex/docs/customize/actions)
- `rex.on` does not provide an appearance startup hook in `init.lua`: event handlers only work in separately running scripts, and a handler in the configuration is warned about and never called. [Lua events](https://www.superlogical.com/rex/docs/automate/lua-events)

## Installed-build verification

A temporary config containing:

```lua
rex.client.queue("client.theme.change", { name = "Catppuccin Mocha" })
```

was checked with `rex config check <temporary-path>`. It exited 1:

```text
rex.client.queue: no client in scope to perform "client.theme.change": nothing is being invoked
```

The temporary file was removed automatically. Live Lua API enumeration confirmed no `rex.config` or `rex.settings` field. The connected client's action listing exposed font increase/decrease/reset, theme change/import, and appearance mode switching, but no numeric font-size setter action. These observations apply to this build, not future versions.

## Decision

There is no documented, verified way in this beta to express the requested persistent global font size and theme as native declarative `init.lua` settings. A custom action is not an equivalent replacement for automatic persistent configuration.

A plist is not required by Rex's Lua configuration format. It is the current repo's external macOS-preferences provisioning mechanism. `nix-modules/darwin/rex.plist` bundles the font size, dark mode, selected theme ID, complete imported theme data, and the explicitly opted-in `rex.client.remoteControl = true` Boolean; nix-darwin imports it on activation. Other external provisioning mechanisms are possible, but would still configure native client preferences rather than add native Lua settings.

Keep the current provisioning until Rex exposes a supported declarative client-settings API. Quit Rex before applying the preferences so cached client values cannot overwrite them. The plist approach is macOS-specific and depends on beta preference keys and theme serialization; it is a workaround, not a documented Rex configuration API.

## macOS app package

[`nix-modules/darwin/rex.nix`](../nix-modules/darwin/rex.nix) packages **Rex Preview 0.1.0 build 1408** from its pinned official DMG. It requires macOS 15 or newer and preserves the vendor-signed universal app, including the matching server/CLI. The Darwin configuration includes it in `environment.systemPackages`; nix-darwin exposes `/Applications/Nix Apps/Rex Beta.app` and the system profile exposes `rex`.

The package was built and smoke-tested on Apple Silicon: deep/strict signature verification, CLI version, an isolated server/terminal, and actual GUI launch with an isolated local server and visible terminal window. The full Darwin configuration also evaluated successfully. No system activation or replacement of the manually installed app was performed. See [packaging evidence and constraints](rex-nix-packaging.md#implementation-verification).

To activate, quit Rex first so its cached preferences cannot overwrite the existing plist import. Run from another terminal:

```sh
sudo darwin-rebuild switch --flake path:.#darwin
```

The `path:` source includes newly added package files even before they are tracked by Git. After successful activation, move the old manually installed `/Applications/Rex Beta.app` out of `/Applications`, update any Dock/login-item references, and launch `/Applications/Nix Apps/Rex Beta.app`. Avoid two installed copies with the same bundle identifier. This is an explicit local cutover; activation does not delete the old app or stop its existing server.

Use Nix for upgrades: update the complete version/build and DMG hash in `rex.nix`, then rebuild. Leave automatic download/installation disabled and do not accept in-app updates for the managed copy. Rex's update checks cannot be disabled, so prompts may remain. Keep `REX_BIN_DIR` precedence in Rex shells, especially on remote servers; the globally installed CLI is not a substitute for the active server's matching CLI.


## Worktrunk integration

The repository now packages the pinned community [`rex-worktrunk`](https://github.com/haxybaxy/rex-worktrunk/tree/dcfd281232beaab2606d1eb4f0deffa16e4762ed) integration with local safety and test-compatibility patches. This is an implemented configuration change, **not an activated or interactively verified rollout**. See the [migration plan and acceptance gates](rex-worktrunk-migration-plan.md) before deploying it.

### Package and configuration boundaries

- [`nix-modules/shared/rex`](../nix-modules/shared/rex) owns the immutable Lua plugin, picker wrapper, upstream license and local patches. Worktrunk comes from the existing unstable overlay (locked version 0.80.0); shared system packages also expose `wt` for direct use.
- [`stow-modules/rex/.config/rex/init.lua`](../stow-modules/rex/.config/rex/init.lua) owns personal bindings and setup options. Its Lua search path includes `/run/current-system/sw/share/rex/?.lua` and `/run/current-system/sw/share/rex/?/init.lua`, loading `/run/current-system/sw/share/rex/rex-worktrunk/init.lua`. The picker entry point is `/run/current-system/sw/bin/rex-worktrunk-picker`. Do not substitute a client-specific `/nix/store` path.
- The wrapper supplies Nix Bash, Worktrunk, Git, fzf, jq, coreutils, gawk and GNU sed, while preserving inherited PATH and `REX_*` variables. Rex itself is not bundled: callbacks must resolve the active server's matching `rex` CLI. [`zshenv.d/99-rex.sh`](../stow-modules/rex/.config/zsh/zshenv.d/99-rex.sh) restores `REX_BIN_DIR` after Nix's system environment setup for both interactive shells and non-interactive Zsh commands used by floats. Keeping it in `zshrc.d` misses floats and causes `rex: command not found` after checkout creation. Re-stow `rex` after moving this hook; no Nix rebuild is required for the hook change.
- The Worktrunk package does not install Rex.app or provision a Rex server; the macOS app is a separate Darwin-only package described above. Every intended remote host needs its own package deployment and Stow config so these same stable paths resolve on that host.

### Bindings and behavior

Keys below are sequences: press Ctrl+Q, then the second key.

| Sequence | Action |
| --- | --- |
| Ctrl+Q then `g` | Open the repository-scoped branch/worktree picker (`worktree`). |
| Ctrl+Q then `d` | Pick a non-main, branch-associated worktree for removal (`worktree_remove`). |
| Ctrl+Q then `w` | Keep Rex's native session picker (`session.switch`). |
| Ctrl+Q then Shift+W | Keep native session creation (`session.new`). |
| Ctrl+Q then `a` / `r` | Keep activity / config reload. |
| Ctrl+Q twice | Send Ctrl+Q through to the terminal. |

The existing pane, tab and palette bindings remain. The picker opens a float in the focused terminal's working directory and delegates Git operations to Worktrunk; it does not `cd` the original shell. Selecting a checkout creates or reuses a Rex session with the default one-shell layout, not `tms`'s separate Neovim and shell windows. Esc cancels; Alt+Enter forces typed branch input rather than a fuzzy-matched existing candidate.

Setup uses `base = "@"`, `remotes = false` and `slugify = false`: new branches start at current HEAD, remote-tracking candidates are disabled, and typed names are not automatically slugified. Worktrunk's default new checkout path is `../repo.branch`, unlike `gwt-add`'s `../BRANCH`; existing worktrees are not relocated. Detached-HEAD checkouts are not offered by these branch-based pickers.

### Session identity and removal safety

Plugin-managed sessions use **`wt:<canonical absolute checkout path>`** for creation, reuse, main-checkout fallback and closure. Canonicalization normalizes symlinks and trailing slashes; removal captures the identity before deleting the directory so closure does not depend on that directory surviving. Same-basename repositories therefore have different identities. Native sessions are not adopted, renamed or destroyed merely because their basename matches; the first plugin visit may create a separate namespaced session. The long label is intentional, and remote servers have their own inventories.

**Removing a checkout can destroy its entire matching Rex session**, terminating running processes and potentially losing unsaved editor buffers. Main is excluded from the removal picker and no force flag is added, but a clean **unmerged** checkout can still be removed while its branch remains. Retaining a branch does not retain files, processes or editor state. A failed Worktrunk removal must leave the session intact; successful removal uses the main checkout as the viewing client's fallback when applicable. Save work and inspect the selection before removing anything.

No global Worktrunk hooks or `GWT_POST_CREATE_HOOK` translation are introduced. Existing project hooks retain Worktrunk's approval prompts and lifecycle: blocking output may appear in the float; background post-hook logs live under `.git/wt/logs/`. Do not add hooks that duplicate the plugin's session creation or destruction, and do not automatically approve project commands.

### Rollout and Remote Control gates

The source changes alone do not prove that a host has the package, that Rex has loaded the config, or that client switching works:

1. Evaluate the Darwin, NixOS and NixOS-cloud configurations; build and run the package checks on Darwin and an intended Linux architecture. Exercise identity and removal against disposable repositories and an isolated Rex server, including unrelated native sessions and closure after filesystem deletion.
2. Quit Rex before Darwin activation: the existing activation imports appearance preferences and enables Remote Control. Deploy the package and Stow configuration together; use the existing on-demand Rex Stow module, not adoption over an unrelated config.
3. Restart Rex after activation and verify **Remote Control** under Rex → Settings → Server → Client Info. The tracked plist enables it at the user's explicit request: this permits other Rex clients to control the app. No unrelated listeners or authentication settings are changed. Without it, a picker callback can create a checkout/session yet fail to show it. The key was identified in the installed app, and its Boolean import was exercised in a disposable preference domain; actual app switching still requires activation and verification. [Current setting reference](https://www.superlogical.com/rex/docs/reference/mac-settings#setting-client-info-remote-control)
4. Run `rex config check`, then `rex config reload` locally on each intended host; reload is refused over remote connections. Validate the merged keymap and the actual float's matching CLI/PATH. [Configuration reference](https://www.superlogical.com/rex/docs/customize/config)
5. Complete the plan's create/switch/cancel/remove, hook, Remote Control-off and existing-binding scenarios locally and from at least one configured NixOS remote session. Build or config checks alone do not verify the floating UI, process termination or remote execution.

No activation, live Rex preference change, or GUI/remote acceptance is claimed by this declarative permission change. Keep the previous Stow config as well as the system generation for rollback: revert the module load and two worktree bindings together with the package, then validate/reload locally. Rollback must not delete worktrees, branches or sessions. To disable Remote Control persistently, also remove or set false the tracked `rex.client.remoteControl` preference before reactivating; a GUI-only change will be overwritten by the next activation.

## Directory picker

Run `j` in zsh to pick a directory with fzf and change into it. Defined in
`nix-modules/shared/zsh/default.nix`, this shell function uses Nix's fzf
package directly and avoids depending on Rex's Option/Meta-key handling.
The same Nix module sources fzf's zsh keybindings and completion directly
from the package, after enabling vi mode, and sets the Catppuccin Mocha colors
through `environment.variables.FZF_DEFAULT_OPTS`. Neither integration nor
theme needs a Stow shell fragment. Apply the Nix configuration and start a
new login shell to load the changes.

