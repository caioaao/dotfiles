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

  programs.chromium.enable = true; # needed to pull Widevine binaries

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
    github-cli
    gum
    just
    jq
    mise
    neovim
    nodejs
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
