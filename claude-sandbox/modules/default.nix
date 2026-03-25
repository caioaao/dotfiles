# Public NixOS module for Claude Code sandbox.
#
# Provides services.claude-sandbox options that wire together
# host infrastructure (bridge, squid) and expose VM configuration knobs.
# The CLI wrapper is added to environment.systemPackages when enabled.

{ microvm, nixpkgs }:

{ config, lib, pkgs, ... }:

let
  cfg = config.services.claude-sandbox;

  vmRunner = import ../lib/make-sandbox.nix {
    inherit nixpkgs microvm;
    system = pkgs.stdenv.hostPlatform.system;
    hypervisor = cfg.hypervisor;
    vcpu = cfg.defaultVcpu;
    mem = cfg.defaultMem;
  };

  cliPackage = pkgs.callPackage ../pkgs/claude-sandbox.nix {
    inherit vmRunner;
    claudeConfigDir = cfg.claudeConfigDir;
    accessLog = cfg.accessLog;
  };
in
{
  imports = [
    ./host/bridge.nix
    ./host/squid.nix
  ];

  options.services.claude-sandbox = {
    claudeConfigDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}/.claude";
      description = "Path to the host's ~/.claude directory (shared read-only with VM).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "caio";
      description = "Host user whose ~/.claude directory is shared with the VM.";
    };

    defaultVcpu = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of vCPUs for the sandbox VM.";
    };

    defaultMem = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "Memory in MB for the sandbox VM.";
    };

    hypervisor = lib.mkOption {
      type = lib.types.enum [ "cloud-hypervisor" "qemu" ];
      default = "cloud-hypervisor";
      description = "Hypervisor backend for the sandbox VM.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cliPackage ];
  };
}
