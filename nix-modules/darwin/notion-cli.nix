# Notion CLI (`ntn`). https://developers.notion.com/cli/get-started/overview
#
# Upstream ships a prebuilt standalone binary per target (links only system
# frameworks) plus an npm package that bundles all five platform binaries in
# one 64MB tarball. We fetch the single darwin-arm64 release archive instead
# of the npm blob, and skip the curl|bash installer (it writes to ~/.local/bin
# and self-updates, both meaningless under nix).
#
# `ntn update` will fail here: the store path is read-only. Bump this file.
#
# Update: read https://ntn.dev/latest.txt for the version, then
# `nix store prefetch-file --name ntn-src <url>` for the hash.
{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
  pname = "notion-cli";
  version = "0.22.8";

  src = fetchurl {
    url = "https://ntn.dev/releases/v${version}/ntn-aarch64-apple-darwin.tar.gz";
    hash = "sha256-v84otDKuue5IuKneozXb7uogxKnlOeTVbChsVzJQPGE=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ntn $out/bin/ntn
    runHook postInstall
  '';

  meta.mainProgram = "ntn";
}
