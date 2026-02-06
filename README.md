# Nix config

Flake-based NixOS config

## Quick start

```sh
bash <(curl --proto '=https' --tlsv1.2 -L https://raw.githubusercontent.com/caioaao/dotfiles/main/bootstrap.sh)
```

## Key concepts

- Nix/NixOS for global configuration, dependency management
- GNU Stow for user configuration - I don't want to deal with home-manager yet

## Update config

## NixOS

```sh
sudo nixos-rebuild switch --flake .#nixos
```

## MacOS

```sh
sudo darwin-rebuild switch --flake .#darwin
```

## References

- https://github.com/esigs/.dotfiles
  A simple flake-based approach with GNU stow

- https://github.com/dustinlyons/nixos-config
  Very feature-complete multi-host config. Uses nix-darwin and home-manager
