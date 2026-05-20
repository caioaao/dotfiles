# pi (Nix package)

Declarative Nix package for [pi](https://github.com/earendil-works/pi), a
terminal-based coding agent.

> **Heads up — April 2026 rename.** Upstream moved from
> `badlogic/pi-mono` (npm scope `@mariozechner/pi-coding-agent`) to
> `earendil-works/pi` (npm scope `@earendil-works/pi-coding-agent`). The CLI
> binary is still `pi`. Background:
> <https://mariozechner.at/posts/2026-04-08-ive-sold-out/>.

## Upgrading to a new version

```bash
cd nix-modules/shared/pi
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

Rebuild — Nix will error with the correct `hash`. Paste it in. (Or compute it
upfront with `nix store prefetch-file --hash-type sha256 <url>`.)

### 2. Regenerate `package-lock.json`

```bash
cd /tmp
npm pack @earendil-works/pi-coding-agent@<new-version>
tar xzf earendil-works-pi-coding-agent-<new-version>.tgz
cd package
npm install --package-lock-only
cp package-lock.json <dotfiles>/nix-modules/shared/pi/package-lock.json
```

### 3. Update the npm deps hash

In `package.nix`, set `npmDepsHash` to `""`:

```nix
npmDepsHash = "";
```

Rebuild — Nix will error with the correct `npmDepsHash`. Paste it in. (Or
compute it upfront with
`nix run nixpkgs#prefetch-npm-deps -- ./package-lock.json`.)

### 4. Final rebuild

```bash
sudo darwin-rebuild switch --flake .#darwin   # or nixos-rebuild on Linux
```

Should succeed. Verify with:

```bash
pi --version
```
