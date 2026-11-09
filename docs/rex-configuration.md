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

[`nix-modules/darwin/rex.nix`](../nix-modules/darwin/rex.nix) packages **Rex Preview 0.1.0 build 1829** from its pinned official DMG. It requires macOS 15 or newer and preserves the vendor-signed universal app, including the matching server/CLI. The Darwin configuration includes it in `environment.systemPackages`; nix-darwin exposes `/Applications/Nix Apps/Rex Beta.app` and the system profile exposes `rex`.

The original build 1408 package was built and smoke-tested on Apple Silicon: deep/strict signature verification, CLI version, an isolated server/terminal, and actual GUI launch with an isolated local server and visible terminal window. The full Darwin configuration also evaluated successfully. No system activation or replacement of the manually installed app was performed. See [packaging evidence and constraints](rex-nix-packaging.md#implementation-verification).

Build 1829 was built on Apple Silicon and passed `rex version` and deep/strict signature verification. Its CLI reports commit `af0c204859ccf584d9392e154d8d9b4e2124635f`, API revision 11 (supports 0–11). The updated Darwin system derivation evaluated successfully; this upgrade was not activated or GUI-tested. The same dependency refresh selects omp 18.17.0 and GitHub CLI 2.103.3; Neovim remains at the latest stable release, 0.12.6. All four packages built, with headless Neovim startup and CLI version smoke checks passing.

To activate, quit Rex first so its cached preferences cannot overwrite the existing plist import. Run from another terminal:

```sh
sudo darwin-rebuild switch --flake path:.#darwin
```

The `path:` source includes newly added package files even before they are tracked by Git. After successful activation, move the old manually installed `/Applications/Rex Beta.app` out of `/Applications`, update any Dock/login-item references, and launch `/Applications/Nix Apps/Rex Beta.app`. Avoid two installed copies with the same bundle identifier. This is an explicit local cutover; activation does not delete the old app or stop its existing server.

Use Nix for upgrades: update the complete version/build and DMG hash in `rex.nix`, then rebuild. Leave automatic download/installation disabled and do not accept in-app updates for the managed copy. Rex's update checks cannot be disabled, so prompts may remain. Keep `REX_BIN_DIR` precedence in Rex shells, especially on remote servers; the globally installed CLI is not a substitute for the active server's matching CLI.


## URL picker

**Ctrl+Q then `u`** runs `open_url`: a top-aligned, half-height floating fzf
picker for URLs in the focused terminal. Tab selects multiple entries, Enter opens them,
and Esc cancels. It recognizes explicit HTTP/HTTPS/FTP/file URLs, bare `www`
domains, IPv4 addresses, Git SSH URLs and quoted GitHub `owner/repo` shorthand,
matching the URL forms provided by tmux's `fzf-tmux-url` plugin.

Implementation lives in [`nix-modules/shared/rex/urls`](../nix-modules/shared/rex/urls):
Lua creates the float without blocking client input; the packaged Python helper
captures the original block with the active server's matching `rex`, unwraps
terminal lines, extracts and deduplicates URLs, and runs fzf. Unlike the tmux
plugin's default screen-only capture, Rex's capture includes scrollback.
Opening uses `open` on macOS or `xdg-open` on Linux **on the server host**;
remote servers therefore need their own desktop opener, just as with the tmux
plugin. No client Remote Control permission is needed.

The shared Rex Nix module installs `rex-urls` alongside `rex-worktrees`; the
existing Rex Stow config loads it and owns the binding. Deploy both before
running `rex config check` and `rex config reload`. No live-server reload or
system activation was performed for this addition.

Verification on macOS: the Nix package built with four extraction regression
tests; the complete config validated with six actions and 32 bindings. An
isolated Rex server ran the actual action, displayed its extracted URL in fzf,
and removed the float on Esc. A separate real-capture/fzf selection smoke
preserved a query string containing `&` through the opener argument, using a
recording opener instead of launching a browser. No Linux desktop or connected
GUI key-sequence check was performed.

2026-11-09: Rex macOS build 1408 showed a blank centered float even though
terminal capture contained eight URLs and the fzf prompt. A forced redraw did
not help; moving the same running float from `y = 0.25` to `y = 0` revealed
the menu. The action now anchors the float at the top to avoid this client
clipping bug. The updated source action was visually verified in the connected
app, including filtering (five of eight URLs), Tab selection and Esc closing
the layer. The updated Darwin package built and all four extraction tests
passed. No extraction or opener changes, system activation or persistent config
reload were performed. After deploying the package, run `rex config reload`.
This client-rendering regression requires a GUI smoke check; the extraction
tests cannot detect it.

## Worktrunk integration

The repository owns its Rex worktree integration: Lua actions and persistent session identity live beside a local terminal picker helper in [`nix-modules/shared/rex/worktrees`](../nix-modules/shared/rex/worktrees). There is no fetched `rex-worktrunk` package or patch stack. The helper retains MIT-licensed picker code adapted from that project; its attribution ships with the package. Worktrunk still owns Git operations and project hooks, and fzf still owns interactive selection. Complete the [rollout gates below](#rollout-and-remote-control-gates) before relying on a deployment.

### Package and configuration boundaries

- [`nix-modules/shared/rex/default.nix`](../nix-modules/shared/rex/default.nix) registers the local `rex-worktrees` package. Its package definition, Lua actions, session registry, picker helper, license and tests live together under [`rex/worktrees`](../nix-modules/shared/rex/worktrees). Worktrunk comes from the existing unstable overlay (locked version 0.80.0); shared system packages also expose `wt` for direct use.
- [`stow-modules/rex/.config/rex/init.lua`](../stow-modules/rex/.config/rex/init.lua) owns personal bindings and setup options. Its Lua search path includes `/run/current-system/sw/share/rex/?.lua` and `/run/current-system/sw/share/rex/?/init.lua`, loading `/run/current-system/sw/share/rex/worktrees/init.lua`. The picker entry point is `/run/current-system/sw/bin/rex-worktree-picker`. Do not substitute a client-specific `/nix/store` path. Deploy this config and the renamed package together; the old module and executable names are not retained.
- The wrapper supplies Nix Bash, Worktrunk, Git, fzf, jq, coreutils, gawk and GNU sed, while preserving inherited PATH and `REX_*` variables. It also supplies GitHub CLI as a PATH fallback, preserving an inherited `gh` when present. Rex itself is not bundled: callbacks must resolve the active server's matching `rex` CLI. [`zshenv.d/99-rex.sh`](../stow-modules/rex/.config/zsh/zshenv.d/99-rex.sh) restores `REX_BIN_DIR` after Nix's system environment setup for both interactive shells and non-interactive Zsh commands used by floats. Keeping it in `zshrc.d` misses floats and causes `rex: command not found` after checkout creation. Re-stow `rex` after moving this hook; no Nix rebuild is required for the hook change.
- The Worktrunk package does not install Rex.app or provision a Rex server; the macOS app is a separate Darwin-only package described above. Every intended remote host needs its own package deployment and Stow config so these same stable paths resolve on that host.

The key-bound Lua action opens a floating terminal and returns immediately: waiting for an interactive picker inside the action would block app input. The helper runs fzf and `wt`, then invokes the local Lua callback with `rex do`. This separate callback still requires Remote Control for app switching; moving ownership into this repository does not remove that permission requirement. The registry deliberately keeps its existing `rex/worktrunk` state path so the cutover preserves checkout-to-session ownership.

### Bindings and behavior

Keys below are sequences: press Ctrl+Q, then the second key.

| Sequence | Action |
| --- | --- |
| Ctrl+Q then `g` | Open the repository-scoped branch/worktree picker (`worktree`). |
| Ctrl+Q then Shift+G | Enter a GitHub PR number or URL and open its worktree (`worktree_pr`). |
| Ctrl+Q then `d` | Pick a non-main, branch-associated worktree for removal (`worktree_remove`). |
| Ctrl+Q then `w` | Keep Rex's native session picker (`session.switch`). |
| Ctrl+Q then Shift+W | Keep native session creation (`session.new`). |
| Ctrl+Q then `a` / `r` | Keep activity / config reload. |
| Ctrl+Q twice | Send Ctrl+Q through to the terminal. |

The existing pane, tab and palette bindings remain. The picker opens a float in the focused terminal's working directory and delegates Git operations to Worktrunk; it does not `cd` the original shell. Selecting a checkout creates or reuses a Rex session with the default one-shell layout, not `tms`'s separate Neovim and shell windows. Esc cancels; Alt+Enter forces typed branch input rather than a fuzzy-matched existing candidate.

Setup uses `base = "@"`, `remotes = false` and `slugify = false`: new branches start at current HEAD, remote-tracking candidates are disabled, and typed names are not automatically slugified. Worktrunk's default new checkout path is `../repo.branch`, unlike `gwt-add`'s `../BRANCH`; existing worktrees are not relocated. Detached-HEAD checkouts are not offered by these branch-based pickers.

### PR checkout

In a repository's terminal, press **Ctrl+Q then Shift+G**, or select **Worktree: check out PR…** in the palette. Enter a PR number such as `123` or a full URL such as `https://github.com/owner/repo/pull/123`. Blank input or Ctrl+C cancels. Numbers use Worktrunk's GitHub repository resolution, including `gh repo set-default`; authenticate `gh` on the server host first.

Worktrunk resolves and fetches the PR branch, creates its checkout when absent, and reuses an existing checkout otherwise. The shared Rex callback then creates or reuses its managed session. The caller's branch and shell directory stay unchanged. Worktrunk retains ownership of fork handling, branch conflicts, checkout paths and hook approval; no `--create`, forced checkout or automatic hook approval is added. Failures remain visible in the float. If app presentation fails after checkout/session creation, those resources remain available.

This entry point belongs to the Nix-packaged Rex module, not the portable GitHub Stow aliases: `gh co` remains `gh pr checkout`, with no Rex dependency. The existing branch picker also accepts `pr:123` or a PR URL via Alt+Enter.

Verification: the Darwin package passed both source and installed-wrapper checks, including PR-number/URL resolution with local forge metadata, checkout reuse, unchanged caller branch, cancellation and failed lookup. The Linux package derivation evaluated; no Linux runtime was exercised. The complete Stow config loaded the new module with five actions and 31 bindings. On an isolated Rex server, the actual `worktree_pr` action displayed its prompt, fetched `cli/cli#14927` through real GitHub CLI and Git, and created a checkout at the reported PR head `d43c4e3ad3c34332c803a568f85f116e3ee58f19`. A URL revisit reused both checkout and native session ID; the caller remained on `main`. No app was connected, so presentation failed explicitly after successful creation/reuse. This does not verify GUI switching or Remote Control permissions.

Deploy the updated Nix package and Rex Stow config together, then reload Rex locally. No system activation or reload of the user's running server was performed for this addition.

### Session identity and removal safety

Session identity is separate from the display label. Each running Rex server has a persistent registry mapping **canonical absolute checkout paths to native session IDs**. Canonicalization normalizes symlinks and trailing slashes. Ordinary lookup uses the saved ID, never a label or basename, so a manual managed-session rename does not break reuse. The picker captures the canonical path before removing a checkout; after successful Worktrunk removal, the plugin resolves that saved path through the registry even though the directory is gone. Main-checkout fallback for the viewing client happens before destroying the removed checkout's session.

Managed labels are the **shortest unique trailing path-component suffixes** across live managed checkout paths. A basename is enough when unique; collisions extend the label with parent components. Native session labels also reserve their names, so a managed suffix extends as needed without renaming, adopting or destroying a native session. Managed labels are recomputed on creation, closure and revisit: removing a collision can shorten surviving labels, and revisiting reapplies the computed label after a manual rename. Control-containing or oversized labels are sanitized and bounded to 128 characters, using a readable path portion plus a native-session-ID discriminator when needed. Display handling never changes the stored canonical path.

Registry files live outside checkouts at `$XDG_STATE_HOME/rex/worktrunk/<server.instance_id>/sessions.json`, falling back to `~/.local/state/rex/worktrunk/<server.instance_id>/sessions.json` when `XDG_STATE_HOME` is unset. The scope comes from `rex.call("server.status").instance_id`, not a client or checkout: a configuration reload or new Lua VM retains the mapping, while a different running-server instance has its own registry. Missing or stale native IDs are pruned. Updates use atomic saves within a transaction protected by a sibling `<server.instance_id>.lock` directory. Lock contention refuses the operation immediately rather than retrying. If interruption leaves a stale, even empty, lock directory, first ensure no worktrunk action is in progress on that server, then manually remove only that instance's lock directory; do not clear an active lock or delete the registry as routine recovery.

On the first initialization of a server instance's registry only, exact legacy **`wt:/absolute/path`** labels are imported; duplicate legacy sessions for the same exact path cause refusal rather than an arbitrary choice. This is a one-time migration, not ordinary label lookup. Native sessions are never adopted by basename. If the registry is lost, short-label sessions cannot be identified safely and are not automatically adopted; a later visit may create a separate managed session. Keep registry state when redeploying or reloading.

**Removing a checkout can destroy its entire matching Rex session**, terminating running processes and potentially losing unsaved editor buffers. Main is excluded from the removal picker and no force flag is added, but a clean **unmerged** checkout can still be removed while its branch remains. Retaining a branch does not retain files, processes or editor state. A failed Worktrunk removal must leave the session intact; successful removal uses the main checkout as the viewing client's fallback when applicable. Save work and inspect the selection before removing anything.

No global Worktrunk hooks or `GWT_POST_CREATE_HOOK` translation are introduced. Existing project hooks retain Worktrunk's approval prompts and lifecycle: blocking output may appear in the float; background post-hook logs live under `.git/wt/logs/`. Do not add hooks that duplicate the plugin's session creation or destruction, and do not automatically approve project commands.

### Local-module verification

The Darwin `rex-worktrees` package built successfully, running the picker behavior harness against both source and installed wrapper. It exercises real Git, Worktrunk and fzf, including current-HEAD and explicit creation bases, forced typed input, cancellation, dirty refusal and successful removal. The harness records Rex callbacks; the separate runtime smoke below uses real callbacks. A disposable copy of the complete Stow config loaded the packaged module with four actions, 30 bindings and no diagnostics. Darwin, NixOS and NixOS-cloud system derivations evaluated successfully.

[`test/session-identity.lua`](../nix-modules/shared/rex/worktrees/test/session-identity.lua) passed against the packaged local module on a real, empty, isolated Rex server: basename labels, expansion of both colliding suffixes, native-label preservation, legacy migration, normalized reuse, manual-rename reuse, closure after deletion, survivor shortening, stale-ID recovery, lock refusal, registry-loss isolation, Unicode/control/length handling and failed-main-presentation safety. No Rex callbacks were mocked.

A real floating-terminal smoke displayed the fzf candidate list and removal warning, accepted typed branch creation, and reached the local Lua callback. Without a connected app, presentation failed visibly while the new checkout and managed session remained available. Dirty removal preserved both checkout contents and the matching live session; a subsequent clean removal deleted the checkout and exactly that session while retaining main and the picker session. The isolated server's callback environment explicitly targeted its private socket.

To repeat the identity regression, follow its fixture comments and give both the isolated server and test CLI the same private `XDG_STATE_HOME`. Use only disposable directories and an explicit private server socket; set `REX_SERVER` and `rex -S` to that socket when launching the server so terminal callbacks cannot target the normal user server. No system activation, user-session relabeling, app switching, interactive hook approval, remote-host execution or Linux runtime check was performed for this cutover. Terminal capture and headless callbacks do not prove app presentation.


### Rollout and Remote Control gates

The source changes alone do not prove that a host has the package, that Rex has loaded the config, or that client switching works:

1. Evaluate the Darwin, NixOS and NixOS-cloud configurations; build and run the package checks on Darwin and an intended Linux architecture. Exercise identity and removal against disposable repositories and an empty isolated Rex server with a private `XDG_STATE_HOME`, including shortest-suffix relabeling on create/close/revisit, unrelated native labels, registry persistence and loss, exact legacy migration, lock refusal, display bounds and closure after filesystem deletion. A no-app server can exercise real session callbacks but cannot prove client presentation.
2. Quit Rex before Darwin activation: the existing activation imports appearance preferences and enables Remote Control. Deploy the package and Stow configuration together; use the existing on-demand Rex Stow module, not adoption over an unrelated config.
3. Restart Rex after activation and verify **Remote Control** under Rex → Settings → Server → Client Info. The tracked plist enables it at the user's explicit request: this permits other Rex clients to control the app. No unrelated listeners or authentication settings are changed. Without it, a picker callback can create a checkout/session yet fail to show it. The key was identified in the installed app, and its Boolean import was exercised in a disposable preference domain; actual app switching still requires activation and verification. [Current setting reference](https://www.superlogical.com/rex/docs/reference/mac-settings#setting-client-info-remote-control)
4. Run `rex config check`, then `rex config reload` locally on each intended host; reload is refused over remote connections. Validate the merged keymap and the actual float's matching CLI/PATH. [Configuration reference](https://www.superlogical.com/rex/docs/customize/config)
   Deploy the updated Lua package before reloading: reloading only the Stow configuration does not install the new registry/label implementation. Package deployment and a local config reload are required on each intended server host; this change has not performed activation, live-session migration or a reload on the user's running server.
5. Exercise create/switch/cancel/remove, current-session fallback, hook approval/output, Remote Control-off failures and existing bindings locally and from at least one configured NixOS remote session. Build or config checks alone do not verify the floating UI, process termination or remote execution.

No system activation or reload of the user's running server was performed for the local-module cutover. Keep the previous Stow config as well as the system generation for rollback: revert the module load and picker executable path together with the package, then validate/reload locally. Rollback must not delete worktrees, branches, registry state or sessions. To disable Remote Control persistently, also remove or set false the tracked `rex.client.remoteControl` preference before reactivating; a GUI-only change will be overwritten by the next activation.

## Directory picker

Run `j` in zsh to pick a directory with fzf and change into it. Defined in
`nix-modules/shared/zsh/default.nix`, this shell function uses Nix's fzf
package directly and avoids depending on Rex's Option/Meta-key handling.
The same Nix module sources fzf's zsh keybindings and completion directly
from the package, after enabling vi mode, and sets the Catppuccin Mocha colors
through `environment.variables.FZF_DEFAULT_OPTS`. Neither integration nor
theme needs a Stow shell fragment. Apply the Nix configuration and start a
new login shell to load the changes.

