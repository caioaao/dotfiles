{ config, lib, pkgs, ... }:

{
  # Set your user and shell
  users.users.caiooliveira = {
    name = "caiooliveira";
    home = "/Users/caiooliveira";
    shell = pkgs.zsh;
  };

  # Nice macOS niceties can go here later (dock, defaults, fonts, etc.)
}
