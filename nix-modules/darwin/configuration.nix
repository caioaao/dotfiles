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
    trust.formulae = [ "withgraphite/tap/graphite" ];
    trust.taps = [ "humanlayer/humanlayer" ];
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
      "humanlayer/humanlayer"
    ];
    brews = [
      "nss"
      "withgraphite/tap/graphite"
    ];
    casks = [
      "ghostty"
      "humanlayer/humanlayer/humanlayer"
      "tailscale-app"
    ];
  };

  system.stateVersion = 6;  # 25.05"
}
