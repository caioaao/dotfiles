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

    # pi - terminal-based coding agent.
    # Renamed from `pi-coding-agent` (npm: @mariozechner/pi-coding-agent) to
    # `pi` (npm: @earendil-works/pi-coding-agent) in April 2026. See
    # https://mariozechner.at/posts/2026-04-08-ive-sold-out/.
    pi.url = "path:./nix-modules/shared/pi";
    pi.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-unstable, nix-darwin, nix-homebrew, determinate, pi, ... }:
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
          oh-my-posh = unstable.oh-my-posh;
          neovim = unstable.neovim;
          pi = pi.packages.${final.system}.default;
        };

      # Builder functions for each box. A downstream flake (e.g. the private
      # config that imports this one) calls these and appends its own
      # `modules` for config it doesn't want landing in this public repo.
      # Each builder closes over this flake's inputs and the unstable
      # overlay. Relative module paths resolve against this flake's source
      # even when called from another flake.
      mkNixos = { modules ? [], specialArgs ? {}, system ? linuxSystem }:
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            { nixpkgs.overlays = [ unstableOverlay ]; }
            ./nix-modules/nixos/configuration.nix
            ./nix-modules/shared/configuration.nix
          ] ++ modules;
        };

      mkNixosCloud = { modules ? [], specialArgs ? {}, system ? linuxSystem }:
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            { nixpkgs.overlays = [ unstableOverlay ]; }
            ./nix-modules/nixos-cloud/configuration.nix
            ./nix-modules/shared/configuration.nix
          ] ++ modules;
        };

      mkDarwin = { modules ? [], specialArgs ? {}, system ? macSystem }:
        nix-darwin.lib.darwinSystem {
          inherit system specialArgs;
          modules = [
            determinate.darwinModules.default
            ({ ... }: { determinateNix.enable = true; })
            { nixpkgs.overlays = [ unstableOverlay ]; }
            nix-homebrew.darwinModules.nix-homebrew
            ./nix-modules/darwin/configuration.nix
            ./nix-modules/shared/configuration.nix
          ] ++ modules;
        };

      lib = { inherit mkNixos mkNixosCloud mkDarwin; };
    in {
      inherit lib;

      # ---------- NixOS ----------
      nixosConfigurations."nixos" = mkNixos {};

      # ---------- NixOS (cloud dev) ----------
      nixosConfigurations."nixos-cloud" = mkNixosCloud {};

      # ---------- darwin ----------
      darwinConfigurations."darwin" = mkDarwin {};
    };
}

