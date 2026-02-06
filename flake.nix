{
  description = "One flake for NixOS + macOS (nix-darwin) with shared config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nix-darwin for macOS system configuration
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # determinate is used in macOS
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs = { nixpkgs, nixpkgs-unstable, nix-darwin, nix-homebrew, determinate, ... }:
    let
      # Pick the CPU/OS for each machine
      linuxSystem = "x86_64-linux";
      macSystem   = "aarch64-darwin";

      # Overlay to bring in specific unstable packages
      unstableOverlay = final: prev:
        let
          unstable = import nixpkgs-unstable {
            system = final.system;
            config.allowUnfree = true;
          };
        in {
          claude-code = unstable.claude-code;
        };
    in {
      # ---------- NixOS ----------
      nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        modules = [
          { nixpkgs.overlays = [ unstableOverlay ]; }
          ./nix-modules/nixos/configuration.nix
          ./nix-modules/shared/configuration.nix
        ];
      };

      # ---------- darwin ----------
      darwinConfigurations."darwin" = nix-darwin.lib.darwinSystem {
        system = macSystem;
        modules = [
	  determinate.darwinModules.default
        ({ ... }: { determinateNix.enable = true; })

          { nixpkgs.overlays = [ unstableOverlay ]; }
          nix-homebrew.darwinModules.nix-homebrew
          ./nix-modules/darwin/configuration.nix
          ./nix-modules/shared/configuration.nix
        ];
      };
    };
}

