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

A plist is not required by Rex's Lua configuration format. It is the current repo's external macOS-preferences provisioning mechanism. `nix-modules/darwin/rex.plist` bundles the font size, dark mode, selected theme ID, and complete imported theme data; nix-darwin imports it on activation. Other external provisioning mechanisms are possible, but would still configure native client preferences rather than add native Lua appearance settings.

Keep the current provisioning until Rex exposes a supported declarative client-settings API. Quit Rex before applying the preferences so cached client values cannot overwrite them. The plist approach is macOS-specific and depends on beta preference keys and theme serialization; it is a workaround, not a documented Rex configuration API.
