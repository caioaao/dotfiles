# ~/.claude overlayfs: host config visible read-only, writes ephemeral (tmpfs).
#
# Mount stack:
#   lower  = /mnt/claude-ro                       (virtiofs share from base.nix, ro)
#   upper  = /home/agent/.claude-overlay/upper     (tmpfs, ephemeral)
#   work   = /home/agent/.claude-overlay/work      (tmpfs, same fs as upper)
#   merged = /home/agent/.claude

{ config, lib, pkgs, ... }:

{
  # Ephemeral backing for the overlay upper + work dirs.
  fileSystems."/home/agent/.claude-overlay" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" "size=512M" ];
  };

  # Ensure upper/ and work/ subdirs exist on the tmpfs before the overlay mounts.
  systemd.tmpfiles.rules = [
    "d /home/agent/.claude-overlay/upper 0700 agent agent -"
    "d /home/agent/.claude-overlay/work  0700 agent agent -"
  ];

  # The overlay itself: host config (ro) + ephemeral writes.
  fileSystems."/home/agent/.claude" = {
    device = "overlay";
    fsType = "overlay";
    options = [
      "lowerdir=/mnt/claude-ro"
      "upperdir=/home/agent/.claude-overlay/upper"
      "workdir=/home/agent/.claude-overlay/work"
    ];
    depends = [ "/mnt/claude-ro" "/home/agent/.claude-overlay" ];
  };
}
