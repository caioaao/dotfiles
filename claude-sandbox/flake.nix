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
    in {
      nixosModules.default = {
        imports = [
          ./modules/host/bridge.nix
          ./modules/host/squid.nix
        ];
      };

      packages.${system}.claude-sandbox =
        let pkgs = nixpkgs.legacyPackages.${system};
        in pkgs.callPackage ./pkgs/claude-sandbox.nix { };

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
