# VM guest networking: DHCP client on the virtio-net NIC + proxy env vars.
#
# The VM has a single TAP interface (MAC 02:00:00:00:00:01) bridged to
# br-sandbox on the host.  The host's dnsmasq serves 10.100.0.2 via DHCP.
#
# Proxy env vars point at the Squid forward proxy on the host (MAIN-21).
# Until Squid is deployed, traffic goes through NAT directly — the env vars
# are harmless when nothing listens on the proxy port.

{ config, lib, pkgs, ... }:

let
  proxyUrl = "http://10.100.0.1:3128";
in
{
  # Use systemd-networkd (matches the host-side bridge.nix pattern).
  systemd.network = {
    enable = true;

    networks."10-vm-eth" = {
      # Match the single virtio-net NIC by its hardcoded MAC (from base.nix).
      matchConfig.MACAddress = "02:00:00:00:00:01";

      networkConfig = {
        DHCP = "ipv4";
        DNS = [ "10.100.0.1" "1.1.1.1" "8.8.8.8" ];
      };

      dhcpV4Config = {
        UseDNS = false;          # use the static DNS above instead
        RouteMetric = 100;
      };
    };
  };

  # System-wide proxy environment variables.
  # NixOS's networking.proxy sets these for all sessions and services.
  networking.proxy = {
    httpProxy = proxyUrl;
    httpsProxy = proxyUrl;
    noProxy = "localhost,127.0.0.1";
  };
}
