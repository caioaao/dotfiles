# Nix Patterns Reference

Concrete examples of common Nix flake and configuration patterns.

## Basic Flake Structure

```nix
{
  description = "My system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {self, nixpkgs, darwin, ...}: {
    # NixOS configuration
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nix-modules/nixos/configuration.nix
        ./nix-modules/shared/configuration.nix
      ];
    };

    # macOS configuration
    darwinConfigurations.hostname = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./nix-modules/darwin/configuration.nix
        ./nix-modules/shared/configuration.nix
      ];
    };
  };
}
```

## System Configuration Patterns

### Shared Package List

**File:** `nix-modules/shared/configuration.nix`

```nix
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # CLI Tools
    git
    ripgrep
    fd
    jq

    # Development
    neovim
    tmux
    direnv

    # Languages (when not using mise)
    nodejs
    python3
  ];

  # Programs with additional config
  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  programs.zsh.enable = true;
}
```

### NixOS-Specific Configuration

**File:** `nix-modules/nixos/configuration.nix`

```nix
{config, pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "my-nixos-machine";
  networking.networkmanager.enable = true;

  # Users
  users.users.myuser = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "docker"];
    shell = pkgs.zsh;
  };

  # Services
  services.openssh.enable = true;
  services.pcscd.enable = true;  # Yubikey support

  # System version
  system.stateVersion = "24.05";
}
```

### macOS-Specific Configuration

**File:** `nix-modules/darwin/configuration.nix`

```nix
{config, pkgs, ...}: {
  # macOS system settings
  system.defaults = {
    dock.autohide = true;
    finder.AppleShowAllExtensions = true;
    NSGlobalDomain.InitialKeyRepeat = 15;
    NSGlobalDomain.KeyRepeat = 2;
  };

  # Homebrew for GUI apps
  homebrew = {
    enable = true;
    casks = [
      "firefox"
      "slack"
      "visual-studio-code"
    ];
  };

  # Users
  users.users.myuser = {
    name = "myuser";
    home = "/Users/myuser";
    shell = pkgs.zsh;
  };

  # System version
  system.stateVersion = 4;
}
```

## Development Shells

### Simple Dev Shell

```nix
{
  outputs = {nixpkgs, ...}: {
    devShells.x86_64-linux.default = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.mkShell {
      buildInputs = with pkgs; [
        nodejs_20
        nodePackages.typescript
        nodePackages.typescript-language-server
      ];

      shellHook = ''
        echo "Node.js dev environment loaded"
        node --version
      '';
    };
  };
}
```

### Multi-Platform Dev Shell

```nix
{
  outputs = {nixpkgs, ...}: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-darwin"];
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          python311
          python311Packages.pip
          python311Packages.virtualenv
        ];
      };
    });
  };
}
```

## Overlays

### Custom Package Overlay

```nix
{
  outputs = {nixpkgs, ...}: {
    overlays.default = final: prev: {
      # Override package version
      customNeovim = prev.neovim.override {
        viAlias = true;
        vimAlias = true;
      };

      # Custom script
      myScript = prev.writeShellScriptBin "my-script" ''
        #!${prev.bash}/bin/bash
        echo "Hello from custom script"
      '';
    };

    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {nixpkgs.overlays = [self.overlays.default];}
        ./configuration.nix
      ];
    };
  };
}
```

## Service Configuration

### Systemd Service (NixOS)

```nix
{config, pkgs, ...}: {
  systemd.services.my-service = {
    description = "My custom service";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];

    serviceConfig = {
      Type = "simple";
      User = "myuser";
      ExecStart = "${pkgs.myPackage}/bin/my-command";
      Restart = "on-failure";
    };
  };
}
```

### LaunchAgent (macOS)

```nix
{config, pkgs, ...}: {
  launchd.user.agents.my-agent = {
    serviceConfig = {
      ProgramArguments = ["${pkgs.myPackage}/bin/my-command"];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
```

## Advanced Patterns

### Conditional Configuration

```nix
{config, pkgs, lib, ...}: {
  environment.systemPackages = with pkgs; [
    git
    neovim
  ] ++ lib.optionals stdenv.isLinux [
    # Linux-only packages
    systemd
    xorg.xauth
  ] ++ lib.optionals stdenv.isDarwin [
    # macOS-only packages
    darwin.apple_sdk.frameworks.Security
  ];
}
```

### Importing Modules

```nix
{
  outputs = {nixpkgs, ...}: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Hardware config
        ./hardware-configuration.nix

        # Custom modules
        ./modules/docker.nix
        ./modules/nvidia.nix

        # Shared and system-specific
        ./nix-modules/shared/configuration.nix
        ./nix-modules/nixos/configuration.nix
      ];
    };
  };
}
```

**Module example:** `modules/docker.nix`

```nix
{config, pkgs, ...}: {
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  users.users.myuser.extraGroups = ["docker"];
}
```

## Testing Patterns

### Quick Test Without Activation

```bash
# Build configuration but don't activate
sudo nixos-rebuild build --flake .#hostname

# Check the result
ls -la result/

# Inspect config
nix eval .#nixosConfigurations.hostname.config.environment.systemPackages --apply builtins.length
```

### Isolated VM Testing (NixOS)

```nix
{
  outputs = {nixpkgs, ...}: {
    nixosConfigurations.test-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          # Minimal config for VM
          fileSystems."/" = {device = "/dev/vda1"; fsType = "ext4";};
          boot.loader.grub.device = "/dev/vda";
          services.xserver.enable = false;
        }
      ];
    };
  };
}
```

```bash
# Build and run VM
nixos-rebuild build-vm --flake .#test-vm
./result/bin/run-*-vm
```

## Debugging Commands

```bash
# Show full config as JSON
nix eval --json .#nixosConfigurations.hostname.config.environment.systemPackages

# Trace evaluation
nix eval --trace-verbose .#nixosConfigurations.hostname.config.system.build.toplevel

# Show derivation
nix derivation show .#nixosConfigurations.hostname.config.system.build.toplevel

# Build with verbose output
nix build -L .#nixosConfigurations.hostname.config.system.build.toplevel
```
