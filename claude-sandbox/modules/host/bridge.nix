{ config, lib, pkgs, ... }:

let
  cfg = config.services.claude-sandbox;
in
{
  options.services.claude-sandbox = {
    enable = lib.mkEnableOption "Claude Code sandbox environment";

    bridge = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "br-sandbox";
        description = "Name of the bridge interface for sandbox VMs.";
      };

      hostAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.100.0.1";
        description = "IP address of the host on the sandbox bridge.";
      };

      vmAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.100.0.2";
        description = "IP address assigned to the VM via DHCP.";
      };

      prefixLength = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "Network prefix length for the sandbox subnet.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Tell NetworkManager to leave sandbox interfaces alone
    networking.networkmanager.unmanaged = [
      "interface-name:${cfg.bridge.name}"
      "interface-name:tap-sandbox*"
    ];

    # IP forwarding for NAT
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    # Bridge device via systemd-networkd
    systemd.network = {
      enable = true;

      netdevs."10-${cfg.bridge.name}" = {
        netdevConfig = {
          Kind = "bridge";
          Name = cfg.bridge.name;
        };
      };

      networks."10-${cfg.bridge.name}" = {
        matchConfig.Name = cfg.bridge.name;
        networkConfig = {
          Address = "${cfg.bridge.hostAddress}/${toString cfg.bridge.prefixLength}";
          ConfigureWithoutCarrier = true;
        };
        linkConfig.RequiredForOnline = "no";
      };
    };

    # NAT for the sandbox subnet (nftables-compatible)
    networking.nat = {
      enable = true;
      internalInterfaces = [ cfg.bridge.name ];
    };

    # DHCP server on the bridge via dnsmasq
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = cfg.bridge.name;
        bind-interfaces = true;

        # Disable DNS (only DHCP)
        port = 0;

        # DHCP range
        dhcp-range = "${cfg.bridge.vmAddress},${cfg.bridge.vmAddress},12h";

        # Default gateway for VMs
        dhcp-option = "option:router,${cfg.bridge.hostAddress}";
      };
    };
  };
}
