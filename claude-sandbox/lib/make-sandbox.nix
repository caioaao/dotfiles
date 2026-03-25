# Build a microVM runner for the Claude Code sandbox.
#
# Returns a derivation with bin/microvm-run and bin/microvm-shutdown.
# The runner expects staging directories at /tmp/claude-sandbox/ to be
# prepared by the CLI before invocation (symlinks for workspace and
# claude-config, params directory with prompt file).

{ nixpkgs, microvm, system
, hypervisor ? "cloud-hypervisor"
, vcpu ? 4
, mem ? 4096
, claudeConfigSource ? "/tmp/claude-sandbox/claude-config"
, workspaceSource ? "/tmp/claude-sandbox/workspace"
, paramsSource ? "/tmp/claude-sandbox/params"
}:

let
  lib = nixpkgs.lib;

  nixos = lib.nixosSystem {
    inherit system;
    modules = [
      microvm.nixosModules.microvm
      ../modules/vm/base.nix
      ../modules/vm/claude-config.nix
      ../modules/vm/network.nix
      ../modules/vm/agent.nix
      {
        microvm = {
          inherit hypervisor vcpu mem;

          # Override share sources from base.nix defaults with the
          # values from module options (or CLI-provided staging paths).
          shares = lib.mkForce [
            {
              tag = "workspace";
              source = workspaceSource;
              mountPoint = "/workspace";
              proto = "virtiofs";
            }
            {
              tag = "claude-config";
              source = claudeConfigSource;
              mountPoint = "/mnt/claude-ro";
              proto = "virtiofs";
              readOnly = true;
            }
            {
              tag = "params";
              source = paramsSource;
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
        };
      }
    ];
  };
in
  nixos.config.microvm.runner.${hypervisor}
