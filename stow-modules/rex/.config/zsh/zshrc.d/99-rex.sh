# Nix replaces PATH during shell startup; keep the CLI paired with this server.
if [ -n "${REX_BIN_DIR:-}" ]; then
    export PATH="$REX_BIN_DIR:$PATH"
fi
