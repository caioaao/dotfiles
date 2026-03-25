# Claude Code agent service: boots into the workspace dev environment,
# sources direnv if present, runs claude, then shuts down the VM.

{ config, lib, pkgs, ... }:

let
  agent-runner = pkgs.writeShellApplication {
    name = "claude-agent-runner";
    runtimeInputs = with pkgs; [ nix direnv ];
    text = ''
      set -euo pipefail

      # Validate prompt is provided
      if [ -z "''${CLAUDE_PROMPT:-}" ]; then
        echo "ERROR: CLAUDE_PROMPT is not set" >&2
        exit 1
      fi

      cd /workspace

      # Source project environment via direnv if .envrc exists.
      # In an ephemeral VM there is no trust database, so we allow unconditionally.
      if [ -f .envrc ]; then
        direnv allow .
        eval "$(direnv export bash 2>/dev/null)"
      fi

      exec nix develop --command claude \
        --dangerously-skip-permissions \
        -p "$CLAUDE_PROMPT"
    '';
  };
in
{
  systemd.services.claude-agent = {
    description = "Claude Code agent task runner";

    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/workspace";
      ExecStart = lib.getExe agent-runner;

      # Ensure all required filesystems are mounted before we start.
      RequiresMountsFor = "/home/agent/.claude /workspace /nix/store";

      # VM lifecycle: shut down the VM when the agent exits (success or failure).
      SuccessAction = "poweroff";
      FailureAction = "poweroff";

      # Hardening (defense-in-depth — the VM itself is the primary sandbox).
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/workspace"
        "/home/agent/.claude"
        "/home/agent/.cache"
        "/nix/.rw-store"
        "/nix/var"
        "/tmp"
      ];
      PrivateTmp = true;
      MemoryMax = "6G";
      CPUQuota = "300%";

      # Journal integration
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "claude-agent";
    };
  };
}
