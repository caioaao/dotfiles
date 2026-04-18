Personal dotfiles: **Nix** (system packages) + **GNU Stow** (user config). Stow modules in `stow-modules/` mirror `$HOME` structure. Nix config in `nix-modules/` (shared, nixos, darwin).

## Commands

```bash
just bootstrap                              # Install all stow modules
just stow <module> true                     # Install a stow module (with adopt)
sudo nixos-rebuild switch --flake .#nixos   # NixOS rebuild
sudo darwin-rebuild switch --flake .#darwin  # macOS rebuild
```

## Docs

- [Stow module patterns](docs/stow-module-patterns.md) — creating/modifying stow modules, pitfalls, testing, rollback
