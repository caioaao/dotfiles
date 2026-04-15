# pi-coding-agent (Nix package)

Declarative Nix package for [pi](https://github.com/badlogic/pi-mono), a
terminal-based coding agent.

## Upgrading to a new version

```bash
cd nix-modules/shared/pi-coding-agent
```

### 1. Update the tarball hash

In `package.nix`, bump `version` and set `hash` to `""`:

```nix
version = "<new-version>";
tarball = fetchurl {
  url = "...pi-coding-agent-${version}.tgz";
  hash = "";
};
```

Rebuild — Nix will error with the correct `hash`. Paste it in.

### 2. Regenerate `package-lock.json`

```bash
cd /tmp
npm pack @mariozechner/pi-coding-agent@<new-version>
tar xzf mariozechner-pi-coding-agent-<new-version>.tgz
cd package
npm install --package-lock-only
cp package-lock.json <dotfiles>/nix-modules/shared/pi-coding-agent/package-lock.json
```

### 3. Update the npm deps hash

In `package.nix`, set `npmDepsHash` to `""`:

```nix
npmDepsHash = "";
```

Rebuild — Nix will error with the correct `npmDepsHash`. Paste it in.

### 4. Final rebuild

```bash
nix build .#darwinConfigurations.darwin.system   # or nixos
```

Should succeed. Verify with:

```bash
result/sw/bin/pi --version
```
