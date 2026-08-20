{ ... }:

{
  # systemd-resolved arbitrates DNS between NetworkManager and tailscaled.
  #
  # Before, both wrote /etc/resolv.conf (last writer wins): tailscaled read
  # the base upstreams at boot before NetworkManager had written them, got
  # an empty list, and answered SERVFAIL for everything outside MagicDNS.
  #
  # With resolved both talk per-link over D-Bus instead of sharing a file:
  #   - NetworkManager pushes the DHCP nameservers for the physical link
  #   - tailscaled pushes 100.100.100.100 + ts.net routes on tailscale0
  #
  # /etc/resolv.conf becomes a symlink to the systemd stub resolver, which
  # fans queries out to the right per-link upstreams.
  services.resolved.enable = true;
}
