{ config, lib, pkgs, ... }:

{
  # Set your user and shell
  users.users.caio = {
    name = "caio";
    home = "/Users/caio";
    shell = pkgs.zsh;
  };

  # Nice macOS niceties can go here later (dock, defaults, fonts, etc.)

  # TODO zsh config between nix-darwin and nixos is incompatible
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;
  };

  system.stateVersion = 6;  # 25.05"
}
