# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a personal dotfiles repository using a hybrid approach:
- **Nix/NixOS** for system-level configuration and package management
- **GNU Stow** for user-level configuration files (avoiding home-manager complexity)
- **Flake-based configuration** supporting both NixOS (Linux) and nix-darwin (macOS)

### Directory Structure

- `flake.nix` - Main Nix flake configuration
- `nix-modules/` - Nix configuration modules
  - `shared/configuration.nix` - Shared packages and programs (both Linux/macOS)
  - `nixos/configuration.nix` - NixOS-specific system configuration
  - `darwin/configuration.nix` - macOS-specific system configuration
- `stow-modules/` - User configuration files managed by GNU Stow
  - Each subdirectory represents a tool/program (git, zsh, nvim, etc.)
  - Files arranged to match `$HOME` directory structure
- `justfile` - Task runner with common operations
- `bootstrap.sh` - Initial system setup script

### Stow Module Pattern

Each stow module follows XDG Base Directory conventions:
- Config files go in `.config/` within the module
- Many modules include `.config/zsh.d/` for shell integration
- The zsh configuration automatically sources all files in `$XDG_CONFIG_HOME/zsh.d/`

## Common Development Commands

### Initial Setup
```bash
# Bootstrap entire system (NixOS/macOS + dotfiles)
sh <(curl --proto '=https' --tlsv1.2 -L https://raw.githubusercontent.com/caioaao/dotfiles/main/bootstrap.sh)

# Or locally after cloning
just bootstrap
```

### System Configuration Updates

**NixOS:**
```bash
sudo nixos-rebuild switch --flake .#nixos
```

**macOS:**
```bash
sudo darwin-rebuild switch --flake .#darwin
```

### Stow Module Management

```bash
# Install a stow module (with adoption of existing files)
just stow <module> adopt=true

# Install without adoption
just stow <module>

# Example modules: git, zsh, nvim, ghostty, mise, ssh
```

### Other Utilities

```bash
# Create XDG base directories
just xdg-base-dirs

# Enroll fingerprint (Linux only)
just enroll-fingerprint
```

## Key Concepts

- **Personal configuration** - Not designed for reusability, optimized for quick environment setup
- **XDG Base Directory compliance** - All configurations follow XDG standards
- **Modular approach** - Each tool/program has its own stow module
- **Shell integration** - zsh automatically loads configurations from all stow modules via `zsh.d/` pattern
- **Cross-platform** - Same dotfiles work on both NixOS and macOS through Nix flakes

## Important Notes

- Stow modules use `$HOME` as target directory
- Files under `stow-modules/<module>/` must be arranged to match final `$HOME` structure
- The main entrypoint is `bootstrap.sh` for fresh systems
- GNU Stow is used instead of home-manager for simplicity
