{
  buildPiPackage,
  lib,
}:

# Linear GraphQL tools + the skill that teaches the agent to use them.
# Self-contained: extension and skills ship in one package directory.
# Dependency-free; auth comes from $LINEAR_API_KEY at runtime.
buildPiPackage {
  pname = "pi-linear";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./index.ts
      ./lib
      ./scripts
      ./skills
    ];
  };

  # Zero runtime deps: the npm deps cache is intentionally empty, and
  # node_modules must exist for the npm install hook's find calls.
  forceEmptyCache = true;
  postPatch = ''
    mkdir -p node_modules
  '';
  npmDepsHash = "sha256-M8Tqc8LMwagDxlNNGo8ADmxunhQsajHVnLtNgocOtiM=";

  meta = {
    description = "pi extension: Linear GraphQL query/mutate/schema tools with an authoring skill";
  };
}
