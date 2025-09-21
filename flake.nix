{
  description = "One flake for NixOS + macOS (nix-darwin) with shared config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # nix-darwin for macOS system configuration
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, ... }:
  let
    # Pick the CPU/OS for each machine
    linuxSystem = "x86_64-linux"; 
    macSystem   = "aarch64-darwin"; 

    # Shared settings used by BOTH machines
    sharedModule = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;
      programs.zsh.enable = true;

      environment.systemPackages = with pkgs; [
        pkgs.git
        pkgs.wget
        pkgs.ripgrep
        pkgs.fd
        pkgs.fzf
        pkgs.neovim
        pkgs.direnv
        pkgs.tmux
        pkgs.stow
        pkgs.just
        pkgs.zoxide
        pkgs.oh-my-zsh
        pkgs._1password-cli
        pkgs.stdenv
        pkgs.unzip
      ];
    };
  in {
    # ---------- NixOS ----------
    nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
      system = linuxSystem;
      modules = [
        ./hosts/nixos/configuration.nix
        sharedModule
      ];
    };

    # ---------- darwin ----------
    darwinConfigurations."darwin" = nix-darwin.lib.darwinSystem {
      system = macSystem;
      modules = [
        ./hosts/darwin/configuration.nix
        sharedModule
      ];
    };
  };
}

