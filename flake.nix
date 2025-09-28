{
  description = "One flake for NixOS + macOS (nix-darwin) with shared config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # nix-darwin for macOS system configuration
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, ... }:
    let
      # Pick the CPU/OS for each machine
      linuxSystem = "x86_64-linux"; 
      macSystem   = "aarch64-darwin"; 
    in {
      # ---------- NixOS ----------
      nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        modules = [
          ./nix-modules/nixos/configuration.nix
          ./nix-modules/shared/configuration.nix
        ];
      };

      # ---------- darwin ----------
      darwinConfigurations."darwin" = nix-darwin.lib.darwinSystem {
        system = macSystem;
        modules = [
          ./nix-modules/darwin/configuration.nix
          ./nix-modules/shared/configuration.nix
        ];
      };
    };
}

