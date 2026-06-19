usage() {
  echo "usage: tsserve-file <file> [port]" >&2
  exit 64
}

# Pick a free TCP port from the IANA dynamic/private range (49152-65535),
# which is reserved for ephemeral/private use and won't collide with
# registered services.
pick_port() {
  local candidate
  for _ in $(seq 1 50); do
    candidate=$((RANDOM % 16384 + 49152))
    # A refused connection means nothing is listening on the port.
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$candidate") 2>/dev/null; then
      echo "$candidate"
      return 0
    fi
    exec 3>&- 2>/dev/null || true
  done
  echo "tsserve-file: could not find a free port" >&2
  return 1
}

[[ $# -ge 1 && $# -le 2 ]] || usage
file=$1

[[ -f $file ]] || {
  echo "tsserve-file: not a file: $file" >&2
  exit 1
}

if [[ $# -eq 2 ]]; then
  port=$2
  [[ $port =~ ^[0-9]+$ ]] || {
    echo "tsserve-file: invalid port: $port" >&2
    exit 1
  }
else
  port=$(pick_port)
fi

miniserve --interfaces 127.0.0.1 --port "$port" -- "$file" &
miniserve_pid=$!
trap 'kill "$miniserve_pid" 2>/dev/null || true' EXIT

tailscale serve "$port"
