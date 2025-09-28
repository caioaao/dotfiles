{ config, lib, pkgs, ... }:

{
  # Set your user and shell
  users.users.caio = {
    name = "caio";
    home = "/Users/caio";
    shell = pkgs.zsh;
  };

  # Nice macOS niceties can go here later (dock, defaults, fonts, etc.)
  system.stateVersion = 6;  # 25.05"
}
