# Run after Nix's system zshenv, including in non-interactive Rex floats.
if [ -n "${REX_BIN_DIR:-}" ]; then
    export PATH="$REX_BIN_DIR:$PATH"
fi
