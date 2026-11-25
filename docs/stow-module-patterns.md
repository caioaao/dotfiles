# GNU Stow Module Patterns

## Layout

Each `stow-modules/<module>/` mirrors `$HOME`. For example,
`stow-modules/foo/.config/foo/config.yaml` maps to `~/.config/foo/config.yaml`.

Stow can symlink a whole directory if it doesn't exist at the destination.
Where managed files must coexist with runtime data, pre-create the real target
directory before stowing. For example, `bootstrap-agents` creates
`~/.agents/skills` so Stow links the managed skill without taking over the
directory. Ignore any unmanaged runtime files that could land in the repo.

Put repo-authored skills shared by Omp and Pi in
`stow-modules/agents/.agents/skills/`. Install with `just stow agents`; both
harnesses discover them there. Keep the Nix-packaged `mattpocock-skills` tree
for upstream skills and their local adaptations. When moving a skill out of
that package, rebuild the active Nix generation before restarting the
harnesses so they do not also discover the old copy.

Zsh fragments live under `.config/zsh/zshenv.d/` for all shells and
`.config/zsh/zshrc.d/` for interactive shells. Prefix filenames with a two-digit
load order: `00`–`19` for early setup, `20`–`49` for tool integrations,
`50`–`79` for aliases/functions, `80`–`99` for late setup.

## Install and verify

1. Check the [justfile](../justfile) for module-specific preparation and create
   any target directories that must stay real.
2. Preview with `stow -n -v -t "$HOME" -d stow-modules <module>`. Check for
   conflicts and unexpected directory symlinks.
3. Install on demand with `just stow <module>`. Use `just stow <module> true`
   only to intentionally import existing files: `--adopt` moves them into the
   repository and can replace tracked contents. Review imported changes.
4. Inspect the symlinks and launch the tool. Verify it can read the config and
   write runtime data outside the repository.

To roll back the links, run `stow -D -t "$HOME" -d stow-modules <module>`.
Unstowing does not undo file changes from `--adopt`.
