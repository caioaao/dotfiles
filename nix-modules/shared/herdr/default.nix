{ pkgs, ... }: {
  # The herdr binary itself is in shared/configuration.nix systemPackages.
  # This module only carries helpers around it.
  #
  # Keybinding lives in stow-modules/herdr/.config/herdr/config.toml
  # ([[keys.command]] on prefix+w). Script and binding are split across
  # nix and stow on purpose: the config stays hand-editable so
  # `herdr server reload-config` (prefix+shift+r) works without a rebuild.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "hws";
      runtimeInputs = [
        pkgs.fzf
        pkgs.herdr
        pkgs.jq
      ];
      text = builtins.readFile ./hws.sh;
    })
  ];
}
