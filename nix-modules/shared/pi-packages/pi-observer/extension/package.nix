{
  buildPiPackage,
  lib,
}:

# pi-observer registry extension (write side of ../CONTRACT.md).
# Dependency-free; the piobs CLI is a separate Go package (../piobs).
buildPiPackage {
  pname = "pi-observer";
  version = "0.2.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./index.ts
      ./lib
    ];
  };

  # Zero runtime deps: the npm deps cache is intentionally empty, and
  # node_modules must exist for the npm install hook's find calls.
  forceEmptyCache = true;
  postPatch = ''
    mkdir -p node_modules
  '';
  npmDepsHash = "sha256-rg4YIpRLs9NpdRTF5e/RfNdcb7Ep6wudycbHmwPgfFQ=";

  meta = {
    description = "pi-observer registry extension: per-session liveness docs";
  };
}
