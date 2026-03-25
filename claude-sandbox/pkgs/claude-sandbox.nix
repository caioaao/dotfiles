# CLI wrapper for launching sandboxed Claude Code microVMs.
#
# Sets up staging directories (symlinks for workspace and claude-config,
# params directory with prompt file), runs the pre-built VM runner,
# and cleans up on exit.

{ writeShellScriptBin, coreutils, util-linux
, vmRunner
, claudeConfigDir ? "$HOME/.claude"
, accessLog ? "/var/log/claude-sandbox/access.log"
}:

writeShellScriptBin "claude-sandbox" ''
  set -euo pipefail

  VM_RUNNER="${vmRunner}"
  CLAUDE_CONFIG_DIR="${claudeConfigDir}"
  ACCESS_LOG="${accessLog}"
  STAGING="/tmp/claude-sandbox"
  LOCK="/tmp/claude-sandbox.lock"

  WORKSPACE=""
  PROMPT=""
  TIMEOUT=""
  PRINT_LOG=false
  INTERACTIVE=false

  usage() {
    cat <<'USAGE'
  Usage: claude-sandbox run [OPTIONS]

  Options:
    --workspace PATH       Path to git worktree (required)
    --prompt TEXT          Prompt for claude (required unless --interactive)
    --timeout SECONDS     Kill VM after N seconds (default: none)
    --interactive         Attach TTY instead of --prompt
    --print-log           Dump Squid access log on exit
    -h, --help            Show this help
  USAGE
    exit "''${1:-0}"
  }

  # ── Argument parsing ───────────────────────────────────────────────
  if [ "''${1:-}" = "run" ]; then
    shift
  elif [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
    usage 0
  elif [ -n "''${1:-}" ]; then
    echo "Unknown command: $1" >&2
    usage 1
  else
    usage 1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --workspace)
        WORKSPACE="$2"; shift 2 ;;
      --prompt)
        PROMPT="$2"; shift 2 ;;
      --timeout)
        TIMEOUT="$2"; shift 2 ;;
      --interactive)
        INTERACTIVE=true; shift ;;
      --print-log)
        PRINT_LOG=true; shift ;;
      -h|--help)
        usage 0 ;;
      *)
        echo "Unknown option: $1" >&2
        usage 1 ;;
    esac
  done

  # ── Validation ─────────────────────────────────────────────────────
  if [ -z "$WORKSPACE" ]; then
    echo "Error: --workspace is required" >&2
    exit 1
  fi

  WORKSPACE="$(${coreutils}/bin/realpath "$WORKSPACE")"

  if [ ! -d "$WORKSPACE" ]; then
    echo "Error: workspace does not exist: $WORKSPACE" >&2
    exit 1
  fi

  if [ "$INTERACTIVE" = false ] && [ -z "$PROMPT" ]; then
    echo "Error: --prompt is required (or use --interactive)" >&2
    exit 1
  fi

  if [ "$INTERACTIVE" = true ]; then
    echo "Error: --interactive mode is not yet implemented" >&2
    exit 1
  fi

  if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
    echo "Error: claude config directory not found: $CLAUDE_CONFIG_DIR" >&2
    exit 1
  fi

  # ── Lock (one VM at a time) ────────────────────────────────────────
  exec 9>"$LOCK"
  if ! ${util-linux}/bin/flock -n 9; then
    echo "Error: another claude-sandbox instance is running" >&2
    exit 1
  fi

  # ── Staging setup ──────────────────────────────────────────────────
  cleanup() {
    rm -rf "$STAGING/params"
    rm -f "$STAGING/workspace" "$STAGING/claude-config"
    rmdir "$STAGING" 2>/dev/null || true
    exec 9>&-
    rm -f "$LOCK"

    if [ "$PRINT_LOG" = true ] && [ -f "$ACCESS_LOG" ]; then
      echo ""
      echo "=== Squid access log ==="
      cat "$ACCESS_LOG"
    fi
  }
  trap cleanup EXIT

  mkdir -p "$STAGING/params"
  ln -sfn "$WORKSPACE" "$STAGING/workspace"
  ln -sfn "$CLAUDE_CONFIG_DIR" "$STAGING/claude-config"

  echo "$PROMPT" > "$STAGING/params/prompt"

  # ── Launch VM ──────────────────────────────────────────────────────
  echo "Starting sandbox VM (workspace: $WORKSPACE)..."

  if [ -n "$TIMEOUT" ]; then
    ${coreutils}/bin/timeout "$TIMEOUT" "$VM_RUNNER/bin/microvm-run" || {
      rc=$?
      if [ $rc -eq 124 ]; then
        echo "VM timed out after ''${TIMEOUT}s"
      fi
      exit $rc
    }
  else
    "$VM_RUNNER/bin/microvm-run"
  fi
''
