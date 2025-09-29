{ pkgs, ... }:

{
  # Set your user and shell
  users.users.caio = {
    name = "caio";
    home = "/Users/caio";
    shell = pkgs.zsh;
  };

  nix-homebrew = {
    enable = true;
    user = "caio";
    autoMigrate = true;
  };

  system.stateVersion = 6;  # 25.05"
}
