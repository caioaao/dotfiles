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

  system.primaryUser = "caio";
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  homebrew = {
    enable = true;
    taps = [
      "withgraphite/tap"
    ];
    brews = [
      "nss"
      "withgraphite/tap/graphite"
    ];
    casks = [
      "ghostty"
    ];
  };

  system.stateVersion = 6;  # 25.05"
}
