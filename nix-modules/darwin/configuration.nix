{ pkgs, ... }:

let
  humanlayer-cli = pkgs.callPackage ./humanlayer-cli.nix { };
  notion-cli = pkgs.callPackage ./notion-cli.nix { };
  namespace-devbox = pkgs.callPackage ./namespace-devbox.nix { };
in {
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

  environment.systemPackages = [ humanlayer-cli notion-cli namespace-devbox ];

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
  programs.omp.settings.modelRoles.default = "anthropic/claude-opus-5-5";

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
