{ pkgs, ... }: {
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
  ];
}
