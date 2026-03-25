{
  description = "Claude Code sandboxed execution environment using NixOS microVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Default VM runner (used by standalone `nix build`)
      defaultRunner = import ./lib/make-sandbox.nix {
        inherit nixpkgs microvm system;
      };
    in {
      # NixOS module for host integration.
      # Provides services.claude-sandbox options, host infrastructure
      # (bridge + squid), and adds the CLI to systemPackages.
      nixosModules.default = import ./modules/default.nix {
        inherit microvm nixpkgs;
      };

      # Standalone CLI package (uses default VM config).
      packages.${system} = {
        claude-sandbox = pkgs.callPackage ./pkgs/claude-sandbox.nix {
          vmRunner = defaultRunner;
        };
        default = self.packages.${system}.claude-sandbox;
      };

      # Validate that the VM guest modules compose and evaluate correctly.
      checks.${system}.vm-base = (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          ./modules/vm/base.nix
          ./modules/vm/claude-config.nix
          ./modules/vm/network.nix
          ./modules/vm/agent.nix
        ];
      }).config.system.build.toplevel;
    };
}
