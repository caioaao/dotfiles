{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
}:

# Builds @plannotator/pi-extension as a Nix-managed local pi package.
#
# The npm tarball ships .ts source files (no bin entry) and is loaded by pi
# from a directory using the manifest in its package.json. We therefore can't
# rely on the default buildNpmPackage installPhase (which runs `npm pack` and
# only keeps files listed in `files`); we need to copy the source *and* the
# resolved production node_modules so pi can resolve runtime imports
# (turndown, @pierre/diffs, @joplin/turndown-plugin-gfm) without a network.

let
  version = "0.19.14";
  tarball = fetchurl {
    url  = "https://registry.npmjs.org/@plannotator/pi-extension/-/pi-extension-${version}.tgz";
    hash = "sha256-L9DRIEEdPquenx+ejxBoUufzxe4Q2eDmN449rOIOIDk=";
  };
  # The published tarball has no package-lock.json. We generate one once
  # (see ./README.md) and graft it onto the unpacked source so buildNpmPackage
  # can do a deterministic `npm ci`.
  srcWithLock = runCommand "plannotator-pi-extension-${version}-src" {} ''
    mkdir -p $out
    tar -xzf ${tarball} -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "plannotator-pi-extension";
  inherit version;
  src = srcWithLock;

  npmDepsHash = "sha256-oiiZsd1UG1nIa7xhnOcUKpyr2J2qWbghXildxE036Ok=";

  # Nothing to build — pi loads the .ts files directly. Skipping `npm run build`
  # also avoids the upstream build script which expects a sibling apps/hook
  # workspace dir we don't ship.
  dontNpmBuild  = true;
  dontNpmPrune  = false;

  # Custom install: keep the source AND its production node_modules in $out so
  # the package can be referenced as a pi local-path package. Default install
  # would discard node_modules.
  installPhase = ''
    runHook preInstall

    # Drop devDeps and peerDeps before copying. The peerDep on pi itself
    # (currently `@mariozechner/pi-coding-agent`, will become
    # `@earendil-works/pi-coding-agent` once plannotator republishes against
    # the new scope) is provided by pi at runtime and would balloon the
    # closure ~250MB.
    npm prune --omit=dev --omit=peer --offline --no-audit --no-fund

    target=$out/lib/node_modules/@plannotator/pi-extension
    mkdir -p "$(dirname "$target")"
    cp -r . "$target"

    # Convenience top-level symlink so consumers (pi settings.json,
    # environment.etc) can reference one stable subpath.
    ln -s lib/node_modules/@plannotator/pi-extension $out/pi-extension

    runHook postInstall
  '';

  meta = {
    description = "Plannotator pi extension — interactive plan review with annotations";
    homepage    = "https://github.com/backnotprop/plannotator";
    license     = with lib.licenses; [ mit asl20 ];
    platforms   = lib.platforms.unix;
  };
}
