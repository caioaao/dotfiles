{
  buildPiPackage,
  lib,
}:

# Local pi package: registry extension + piobs CLI. Source lives next to
# this file; node_modules comes from the npm deps cache, never from git.
buildPiPackage {
  pname = "pi-observer";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./index.ts
      ./cli.ts
      ./lib
    ];
  };

  npmDepsHash = "sha256-OOQqNX/a2xsk2X3R8H0vSFySOlMTzEvUNcp/6G75OhU=";

  meta = {
    description = "Big-picture feed of active pi sessions: registry extension + piobs CLI";
    mainProgram = "piobs";
  };
}
