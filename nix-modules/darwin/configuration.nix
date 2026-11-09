{ pkgs, ... }:

let
  humanlayer-cli = pkgs.callPackage ./humanlayer-cli.nix { };
  notion-cli = pkgs.callPackage ./notion-cli.nix { };
  namespace-devbox = pkgs.callPackage ./namespace-devbox.nix { };
  rex-macos = pkgs.callPackage ./rex.nix { };
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
    trust.taps = [
      "humanlayer/humanlayer"
      "datadog-labs/pack"
    ];
  };

  environment.systemPackages = [ notion-cli namespace-devbox rex-macos pkgs.poppler-utils ];

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
    # Native self-hosted MCP: https://langfuse.com/docs/api-and-data-platform/features/mcp-server
    # Export LANGFUSE_BASE_URL, LANGFUSE_PUBLIC_KEY, and LANGFUSE_SECRET_KEY before
    # starting omp. Resolve Basic auth at connection time, never in the Nix store.
    langfuse = {
      type = "http";
      url = "\${LANGFUSE_BASE_URL}/api/public/mcp";
      headers.Authorization = ''!printf 'Basic '; printf '%s:%s' "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" | ${pkgs.coreutils}/bin/base64 --wrap=0'';
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
  # Import appearance/layout and the explicitly opted-in Remote Control permission.
  # Quit Rex before rebuilding so its cached preferences cannot overwrite these.
  system.activationScripts.postActivation.text = ''
    /usr/bin/sudo -u caio /usr/bin/defaults import com.superlogical.rex ${./rex.plist}
  '';

  homebrew = {
    enable = true;
    taps = [
      "humanlayer/humanlayer"
      "datadog-labs/pack"
    ];
    brews = [
      "nss"
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
