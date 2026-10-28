{ pkgs, ... }:

let
  humanlayer-cli = pkgs.callPackage ./humanlayer-cli.nix { };
  notion-cli = pkgs.callPackage ./notion-cli.nix { };
  namespace-devbox = pkgs.callPackage ./namespace-devbox.nix { };
in {
  imports = [ ./raycast.nix ];

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
    trust.taps = [
      "humanlayer/humanlayer"
      "datadog-labs/pack"
    ];
  };

  environment.systemPackages = [ notion-cli namespace-devbox pkgs.poppler-utils ];

  # Raycast Store extensions; run `raycast-sync` to install missing ones.
  # Raycast itself is installed outside nix. See ./raycast.nix.
  programs.raycast.extensions = [
    "mooxl/coffee"
  ];

  # omp MCP servers for this box; see nix-modules/shared/omp.
  # TablePlus.app is installed outside nix; tableplus-mcp ships inside it.
  programs.omp.mcpServers = {
    tableplus = {
      type = "stdio";
      command = "/Applications/TablePlus.app/Contents/MacOS/tableplus-mcp";
    };
    datadog = {
      type = "http";
      url = "https://mcp.datadoghq.com/v1/mcp";
    };
  };

  # omp settings overlay for this box; see nix-modules/shared/omp.
  programs.omp.settings.modelRoles.default = "openai-codex/gpt-6.1-sol";

  system.primaryUser = "caio";
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  # Rex's client preferences are separate from its server-side init.lua.
  # Import only appearance/layout keys; preserve unrelated native preferences.
  # Quit Rex before rebuilding so its cached preferences cannot overwrite these.
  system.activationScripts.postActivation.text = ''
    /usr/bin/sudo -u caio /usr/bin/defaults import com.superlogical.rex ${./rex.plist}
  '';

  homebrew = {
    enable = true;
    taps = [
      "withgraphite/tap"
      "humanlayer/humanlayer"
      "datadog-labs/pack"
    ];
    brews = [
      "nss"
      "withgraphite/tap/graphite"
      "datadog-labs/pack/pup"
    ];
    casks = [
      "anytype"
      "ghostty"
      "humanlayer/humanlayer/humanlayer"
      "tailscale-app"
    ];
  };

  system.stateVersion = 6;  # 25.05"
}
