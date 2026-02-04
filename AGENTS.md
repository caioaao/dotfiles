# CLAUDE.md / AGENTS.md

This file provides comprehensive guidance for LLM agents (Claude Code, sub-agents, etc.) when working with code in this repository.

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

## GNU Stow Module Patterns

### Directory Structure Requirements

**Critical Rule:** Files under `stow-modules/<module>/` must exactly mirror the target `$HOME` directory structure.

**Example:**
```
Target: ~/.config/foo/config.yaml
Stow:   stow-modules/foo/.config/foo/config.yaml
        └─ mirrors $HOME ─┘
```

### Preventing Parent Directory Symlinking

**Problem:** When a directory contains both managed config and unmanaged runtime data, stow will symlink the entire directory by default, causing conflicts.

**Example Scenario:**
```
~/.tool/
├── config.yaml         # Want to manage this
├── agents/             # Want to manage this
├── cache/              # DON'T want to manage (runtime data)
└── history.jsonl       # DON'T want to manage (runtime data)
```

**Solution:** Pre-create subdirectories before stowing to force file-level symlinking:

```just
bootstrap:
    # Create subdirectories BEFORE stowing
    mkdir -p $HOME/.tool/agents
    mkdir -p $HOME/.tool/skills

    just stow tool-module adopt=true
```

**Result:** Stow creates individual symlinks instead of symlinking the entire parent:
```
~/.tool/
├── config.yaml -> ../dotfiles/stow-modules/tool/.tool/config.yaml
├── agents/ -> ../dotfiles/stow-modules/tool/.tool/agents/
├── cache/              # Unmanaged, created by tool at runtime
└── history.jsonl       # Unmanaged, created by tool at runtime
```

**When to Use This Pattern:**
- Application directories with mixed managed/unmanaged content
- Config directories that tools also write runtime data to
- Any directory where the application creates files dynamically

### Gitignore for Runtime Data

When managing directories with runtime data, explicitly exclude unmanaged files:

```gitignore
# Good: Exclude runtime data within managed stow modules
stow-modules/tool/.tool/cache/
stow-modules/tool/.tool/history.jsonl
stow-modules/tool/.tool/plugins/
stow-modules/tool/.tool/state/
```

**Pattern Recognition:**
- `cache/`, `plugins/`, `state/` - Usually runtime directories
- `*.log`, `*.jsonl`, `*.db` - Usually runtime files
- `history.*`, `session.*` - Usually runtime session data

### Stow Installation Workflow

**Always follow this sequence:**

1. **Dry run to preview:**
   ```bash
   stow -n -v -t $HOME -d stow-modules <module>
   # Or check justfile for any pre-stow setup (mkdir commands, etc.)
   ```

2. **Review output:**
   - Check which symlinks will be created
   - Verify no unexpected parent directories are being symlinked
   - Look for conflicts with existing files

3. **Create parent directories if needed:**
   ```bash
   mkdir -p $HOME/.tool/subdir1
   mkdir -p $HOME/.tool/subdir2
   ```

4. **Install with adopt:**
   ```bash
   just stow <module> adopt=true
   ```

5. **Verify symlinks:**
   ```bash
   ls -la ~/.tool/
   cat ~/.tool/config  # Test file is accessible
   ```

**Adopt Flag (`--adopt`):**
- Use during initial bootstrap: `adopt=true`
- Adopts existing files into the stow module (moves them to stow-modules)
- Useful for migrating existing configs
- Always review adopted files afterward to ensure correctness

### Installing Modules Independently

Modules are installed independently as needed, not added to bootstrap:

```bash
# If tool has subdirs with mixed content, create them first
mkdir -p $HOME/.tool/managed-subdir

# Then install the module
just stow tool adopt=true
```

**Key Point:** Keep bootstrap minimal. Install additional modules on-demand rather than cluttering the bootstrap recipe.

### Common Pitfalls

#### ❌ Wrong: Entire directory symlinked
```bash
# Forgot to mkdir subdirectories
just stow tool

# Result:
~/.tool -> ../dotfiles/stow-modules/tool/.tool/
# Problem: Tool can't write runtime data to this directory
```

#### ✅ Correct: Individual items symlinked
```bash
# Create subdirs first
mkdir -p $HOME/.tool/agents
mkdir -p $HOME/.tool/skills

just stow tool

# Result:
~/.tool/
├── config -> ../dotfiles/.../config
├── agents -> ../dotfiles/.../agents/
└── cache/  # Created by tool at runtime - no conflict
```

#### ❌ Wrong: Module structure doesn't mirror $HOME
```
stow-modules/tool/
└── config/
    └── tool/
        └── config.yaml

# Target would be: ~/config/tool/config.yaml (wrong!)
```

#### ✅ Correct: Module structure mirrors $HOME exactly
```
stow-modules/tool/
└── .config/
    └── tool/
        └── config.yaml

# Target: ~/.config/tool/config.yaml (correct!)
```

### Shell Integration Pattern

Many stow modules include zsh integration via the `zsh.d/` pattern:

```
stow-modules/tool/
└── .config/
    └── zsh.d/
        └── 50-tool.sh  # Sourced by zsh automatically
```

**Naming convention:** `NN-tool.sh` where NN is load order (00-99)
- `00-19`: Early initialization (paths, environment)
- `20-49`: Tool-specific configs
- `50-79`: Aliases and functions
- `80-99`: Late initialization (prompts, hooks)

**When to add shell integration:**
- Tool requires environment variables
- Tool provides shell completions
- Tool needs aliases/functions for convenience
- Tool has shell hooks (direnv, mise, etc.)

### Testing New Modules

Before committing a new stow module:

1. **Test on current machine:**
   ```bash
   stow -n -v -t $HOME -d stow-modules new-module  # Dry run
   just stow new-module adopt=true                  # Install
   ls -la ~/.config/tool/                           # Verify
   ```

2. **Verify tool still works:**
   - Launch the tool
   - Check it can read config
   - Verify it can write runtime data (if applicable)

3. **Check git status:**
   ```bash
   git status
   # Ensure only intended files are tracked
   # Verify runtime data is gitignored
   ```

### Rollback Procedure

If a stow module causes issues:

```bash
# Unstow the module (no just recipe, use stow directly)
stow -D -t $HOME -d stow-modules problematic-module

# Verify symlinks removed
ls -la ~/.config/tool/

# Fix the module, then re-stow
just stow problematic-module adopt=true
```

### Quick Reference

**Create a new stow module:**
```bash
# 1. Create structure
mkdir -p stow-modules/new-tool/.config/new-tool

# 2. Add config files
vim stow-modules/new-tool/.config/new-tool/config.yaml

# 3. Add to gitignore (if needed)
echo "stow-modules/new-tool/.config/new-tool/cache/" >> .gitignore

# 4. Test install (dry run)
stow -n -v -t $HOME -d stow-modules new-tool

# 5. If tool has subdirs with runtime data, add mkdir to justfile bootstrap
#    BEFORE the stow command (see bootstrap recipe for examples)

# 6. Install
just stow new-tool adopt=true

# Module is now installed and will be tracked in git
# No need to add to bootstrap - install modules on-demand
```

**Debug stow issues:**
```bash
# Dry run to see what would be linked
stow -n -v -t $HOME -d stow-modules <module>

# Check symlinks
ls -la ~/.config/tool/
readlink ~/.config/tool/config.yaml

# Unstow if needed (note: no just recipe for unstow, use stow directly)
stow -D -t $HOME -d stow-modules <module>
```

---

**Key Principle:** Stow is simple but unforgiving. The most common issues come from:
1. Not mirroring $HOME structure exactly
2. Symlinking entire directories when you meant to symlink contents
3. Forgetting to gitignore runtime data

Always dry-run first, verify symlinks, and test the tool still works.
