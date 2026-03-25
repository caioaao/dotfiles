{
  description = "Claude Code sandboxed execution environment using NixOS microVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm, ... }: {
    nixosModules.default = import ./modules/host/bridge.nix;

    packages.x86_64-linux.claude-sandbox =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.callPackage ./pkgs/claude-sandbox.nix { };
  };
}
