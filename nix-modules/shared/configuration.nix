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
in {
  imports = [
    ./tmux/configuration.nix
  ];
  nixpkgs.config.allowUnfree = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  environment.systemPackages = with pkgs; [
    git
    wget
    ripgrep
    fd
    fzf
    direnv
    stow
    just
    oh-my-zsh
    _1password-cli
    stdenv
    unzip
    mise
    git-spice
    claude-code
    nixd
  ];
}
