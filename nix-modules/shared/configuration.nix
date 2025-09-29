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

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    git
    wget
    ripgrep
    fd
    fzf
    direnv
    stow
    just
    _1password-cli
    stdenv
    unzip
    mise
    git-spice
    claude-code
    nixd
    neovim
    oh-my-posh
    github-cli
  ];
}
