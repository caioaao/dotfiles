{ config, lib, pkgs, ... }:

{
  # nix-daemon + flakes on macOS:
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set your user and shell
  users.users.caio = {
    name = "caio";
    home = "/Users/caio";
    shell = pkgs.zsh;
  };

  # Nice macOS niceties can go here later (dock, defaults, fonts, etc.)
}
