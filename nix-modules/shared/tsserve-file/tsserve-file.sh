usage() {
  echo "usage: tsserve-file <file> <port>" >&2
  exit 64
}

[[ $# -eq 2 ]] || usage
file=$1
port=$2

[[ -f $file ]] || {
  echo "tsserve-file: not a file: $file" >&2
  exit 1
}
[[ $port =~ ^[0-9]+$ ]] || {
  echo "tsserve-file: invalid port: $port" >&2
  exit 1
}

miniserve --interfaces 127.0.0.1 --port "$port" -- "$file" &
miniserve_pid=$!
trap 'kill "$miniserve_pid" 2>/dev/null || true' EXIT

tailscale serve "$port"
