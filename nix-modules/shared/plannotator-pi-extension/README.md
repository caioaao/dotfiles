# plannotator-pi-extension (Nix package)

Declarative Nix build of [`@plannotator/pi-extension`](https://www.npmjs.com/package/@plannotator/pi-extension)
so the package can be loaded as a [pi local-path package](https://github.com/earendil-works/pi)
without a global npm install.

The build output is exposed at the stable path
`/etc/pi-packages/plannotator-pi-extension` (via `environment.etc` in
`nix-modules/shared/configuration.nix`) and referenced from
`stow-modules/pi/.pi/agent/settings.json`.

## Upgrading to a new version

```bash
cd nix-modules/shared/plannotator-pi-extension
```

### 1. Update the tarball hash

In `package.nix`, bump `version` and clear `hash`:

```nix
version = "<new-version>";
tarball = fetchurl {
  url  = ".../pi-extension-${version}.tgz";
  hash = "";
};
```

Rebuild — Nix will error with the correct SRI hash. Paste it in.

### 2. Regenerate `package-lock.json`

The published tarball has no lockfile, so we generate one from the package's
declared `dependencies` and check it in:

```bash
cd /tmp
npm pack @plannotator/pi-extension@<new-version>
tar xzf plannotator-pi-extension-<new-version>.tgz
cd package
npm install --package-lock-only --omit=dev
cp package-lock.json <dotfiles>/nix-modules/shared/plannotator-pi-extension/package-lock.json
```

### 3. Update the npm deps hash

In `package.nix`, set `npmDepsHash = ""` and rebuild. Nix will print the
correct SRI hash; paste it in.

### 4. Final rebuild

```bash
sudo darwin-rebuild switch --flake .#darwin   # or nixos-rebuild on Linux
```

Verify the new path is mounted:

```bash
ls /etc/pi-packages/plannotator-pi-extension
pi list   # should show the local-path package
```
