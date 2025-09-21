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
    pkgs.git
    pkgs.wget
    pkgs.ripgrep
    pkgs.fd
    pkgs.fzf
    pkgs.direnv
    pkgs.stow
    pkgs.just
    pkgs.oh-my-zsh
    pkgs._1password-cli
    pkgs.stdenv
    pkgs.unzip
    pkgs.mise
    git-spice
  ];
}
