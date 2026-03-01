{ pkgs, ... }: 
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
in {
  imports = [
    ./tmux/default.nix
    ./zsh/default.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    _1password-cli
    claude-code
    direnv
    fd
    fzf
    git
    git-revise
    git-spice
    git-lfs
    github-cli
    gum
    just
    jq
    mise
    neovim
    nixd
    obsidian
    oh-my-posh
    ripgrep
    stdenv
    stow
    unzip
    wget
  ];
}
