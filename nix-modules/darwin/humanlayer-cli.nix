# HumanLayer CLI (`humanlayer`). Upstream distributes it as npm package
# @humanlayer/cli, a node launcher that execs a prebuilt standalone binary
# from a platform-specific package. We skip the launcher and install the
# darwin-arm64 binary directly (bun-compiled, links only system dylibs).
#
# Update: bump version, then `nix hash file --sri <tarball>` for hash.
{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
  pname = "humanlayer-cli";
  version = "0.31.16";

  src = fetchurl {
    url = "https://registry.npmjs.org/@humanlayer/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
    hash = "sha256-OT7VSsgBfginvUWIOhSdN2ggfW68a4+jp9y/2Un6VpE=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/humanlayer $out/bin/humanlayer
    runHook postInstall
  '';

  meta.mainProgram = "humanlayer";
}
