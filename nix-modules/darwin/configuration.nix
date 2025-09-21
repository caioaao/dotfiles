{ config, lib, pkgs, ... }:

{
  # nix-daemon + flakes on macOS:
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set your user and shell
  users.users.caiooliveira = {
    name = "caiooliveira";
    home = "/Users/caiooliveira";
    shell = pkgs.zsh;
  };

  # Nice macOS niceties can go here later (dock, defaults, fonts, etc.)
}
