{ pkgs, lib, ... }:
let
  # git-spice package has a test error
  git-spice = pkgs.buildGoModule rec {
    pname = "git-spice";
    version = "0.16.1";
    src = pkgs.fetchFromGitHub {
      owner = "abhinav";
      repo  = "git-spice";
      rev   = "v${version}";
      hash  = "sha256-SILcEXyUo73c8gPDDESCkm/eQIh8elM850qwJqTyO6E=";
    };
    vendorHash = "sha256-T6zSwQdDWYQqe8trIlhpU8dUQXtz8OGmnW5L5AVjGn8=";
    subPackages = [ "." ];
  };

  # Pi extensions/packages as nix derivations. Referenced from
  # ~/.pi/agent/settings.json via /run/current-system/sw/share/pi/packages/.
  pi-packages = pkgs.callPackage ./pi-packages { };

  # Observer TUI for pi sessions; plain Go binary, deliberately not a
  # pi package (see pi-packages/pi-observer/CONTRACT.md).
  piobs = pkgs.callPackage ./pi-packages/pi-observer/piobs/package.nix { };
in {
  imports = [
    ./tmux/default.nix
    ./tsserve-file/default.nix
    ./zsh/default.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  programs.direnv.enable = true;

  # Expose pi packages at /run/current-system/sw/share/pi/packages;
  # only whitelisted share/ subdirs get linked into the system path.
  environment.pathsToLink = [ "/share/pi" ];

  environment.systemPackages = with pkgs; [
    _1password-cli
    bc
    claude-code
    direnv
    fd
    fzf
    gemini-cli
    git
    git-revise
    git-spice
    git-lfs
    pi
    pi-packages
    piobs
    github-cli
    gum
    just
    jq
    mise
    neovim
    nodejs
    tree-sitter
    nixd
    oh-my-posh
    ripgrep
    gcc
    stow
    unzip
    wget
  ];
}
