{
  lib,
  buildNpmPackage,
}:

# Build a pi package (extensions/skills/prompts/themes) as a nix derivation.
#
# Pi loads packages from absolute local paths listed in settings.json
# (`packages`). Each derivation installs a regular npm-style tree under
# $out/lib/node_modules/<npm-name> and exposes a stable alias at
# $out/share/pi/packages/<pname>, so settings.json can reference
# /run/current-system/sw/share/pi/packages/<pname> - a path that survives
# rebuilds and garbage collection.
#
# Peer dependencies are intentionally not installed (--legacy-peer-deps):
# pi bundles its core packages (@earendil-works/*, typebox) and resolves
# them from its own module root. This matches what `pi install` does
# (it installs with --omit=peer / --legacy-peer-deps).
#
# Sources that ship without a package-lock.json need one vendored next to
# the package.nix and passed via `packageLock` (same trick as
# nix-modules/shared/pi/package.nix uses for pi itself).

{
  pname,
  version,
  src,
  npmDepsHash,
  packageLock ? null,
  npmFlags ? [ ],
  postInstall ? "",
  ...
}@args:

buildNpmPackage (
  removeAttrs args [ "packageLock" ]
  // {
    # Extensions are TypeScript loaded via jiti at runtime; nothing to build.
    dontNpmBuild = args.dontNpmBuild or true;

    npmFlags = [ "--legacy-peer-deps" ] ++ npmFlags;

    postPatch = lib.optionalString (packageLock != null) ''
      rm -f npm-shrinkwrap.json
      cp ${packageLock} package-lock.json
    '' + (args.postPatch or "");

    # Make share/pi/packages/<pname> the real directory and point
    # lib/node_modules/<name> at it, not the other way around: node refuses
    # to type-strip .ts files whose (real) path contains node_modules, and
    # extension sources stay TypeScript. Symlinks are resolved to realpaths,
    # so bin scripts keep working.
    postInstall = ''
      root=$out/lib/node_modules
      entry=$(ls "$root")
      case "$entry" in @*) entry="$entry/$(ls "$root/$entry")" ;; esac
      mkdir -p $out/share/pi/packages
      mv "$root/$entry" "$out/share/pi/packages/${pname}"
      ln -s "$out/share/pi/packages/${pname}" "$root/$entry"
    '' + postInstall;
  }
)
