# VM guest base module: microVM definition + virtiofs shares + Nix store overlay.
#
# This is a composable NixOS module — it sets microvm.* options and expects
# the caller (make-sandbox.nix or a flake check) to import
# microvm.nixosModules.microvm so those options exist.
#
# virtiofs tag convention (must match between host and guest):
#   "workspace"      → /workspace        (rw, git worktree)
#   "claude-config"  → /mnt/claude-ro    (ro, host's ~/.claude)
#   "nix-store"      → /nix/.ro-store    (ro, host's /nix/store)

{ config, lib, pkgs, ... }:

{
  # ── microVM hardware ──────────────────────────────────────────────
  microvm = {
    hypervisor = lib.mkDefault "cloud-hypervisor";
    vcpu = lib.mkDefault 4;
    mem = lib.mkDefault 4096;

    # TAP interface — host-side bridge attachment is handled by bridge.nix
    interfaces = [{
      type = "tap";
      id = "tap-sandbox0";
      mac = "02:00:00:00:00:01";
    }];

    # ── virtiofs shares ───────────────────────────────────────────
    # proto MUST be "virtiofs" (default is "9p").
    # microvm.nix auto-generates fileSystems entries for each share.
    shares = [
      {
        tag = "workspace";
        source = lib.mkDefault "/tmp/claude-sandbox/workspace";
        mountPoint = "/workspace";
        proto = "virtiofs";
      }
      {
        tag = "claude-config";
        source = lib.mkDefault "/tmp/claude-sandbox/claude-config";
        mountPoint = "/mnt/claude-ro";
        proto = "virtiofs";
        readOnly = true;
      }
      {
        tag = "params";
        source = lib.mkDefault "/tmp/claude-sandbox/params";
        mountPoint = "/run/claude-sandbox-params";
        proto = "virtiofs";
        readOnly = true;
      }
      {
        tag = "nix-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
        readOnly = true;
      }
    ];

    # ── Nix store overlay ─────────────────────────────────────────
    # microvm.nix builds the overlayfs automatically:
    #   lower  = /nix/.ro-store       (virtiofs share above)
    #   upper  = /nix/.rw-store/store (tmpfs below)
    #   work   = /nix/.rw-store/work  (tmpfs below)
    #   merged = /nix/store
    # source = "/nix/store" on a share sets storeOnDisk = false automatically.
    writableStoreOverlay = "/nix/.rw-store";
  };

  # Ephemeral backing for the writable Nix store overlay layer.
  # Writes (e.g. from `nix develop`) go here and vanish on shutdown.
  fileSystems."/nix/.rw-store" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" "size=2G" ];
    neededForBoot = true;
  };

  # ── minimal NixOS guest config ──────────────────────────────────
  users.users.agent = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/agent";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Keep the image small
  documentation.enable = false;

  networking.hostName = lib.mkDefault "claude-sandbox";

  system.stateVersion = "25.11";
}
