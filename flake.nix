{
  description = "Caio's packages + devshells (Stow manages dotfiles)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
  let
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    forAllSystems = f: builtins.listToAttrs (map (system: { name = system; value = f system; }) systems);
  in {
    # One atomic "bundle" you can install to your profile
    packages = forAllSystems (system:
      let pkgs = import nixpkgs { inherit system; };
          lib  = pkgs.lib;
      in {
        base = pkgs.buildEnv {
          name = "Base set of packages";
          paths = [
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
                  ]
            ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.gnugrep pkgs.coreutils pkgs.findutils pkgs.gnused # GNU tools on macOS
            ];
        };
      });

    # Per-project shells (keep them minimal)
    devShells = forAllSystems (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        default = pkgs.mkShell { packages = with pkgs; [ git ripgrep fd fzf just ]; };
        go = pkgs.mkShell { packages = with pkgs; [ go gopls delve ]; };
        py = pkgs.mkShell { packages = with pkgs; [ python3 uv pipx ]; };
      });
  };
}

