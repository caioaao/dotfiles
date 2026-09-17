# Namespace Devbox CLI (`devbox`). https://namespace.so/docs/devbox
#
# Upstream ships a prebuilt static Go binary per target (links only system
# dylibs) via GoReleaser-style tarballs. We skip the curl|bash installer: it
# resolves the latest version through a VersionsService endpoint, then runs
# `devbox install`, which just copies the binary to ~/.local/bin.
#
# Not the nixpkgs `devbox` (Jetify's shell/container tool). Same binary name,
# unrelated project. Do not install both.
#
# `devbox update` will fail here: the store path is read-only. Bump this file.
#
# Update: the VersionsService response has the version and sha256 for
# every target, so no prefetch is needed:
#   curl -fsSL -X POST -H 'Content-Type: application/json' -d '{"devbox":{}}' \
#     https://private-api.global.namespaceapis.com/nsl.versions.VersionsService/GetLatest
#   nix hash convert --hash-algo sha256 --to sri <sha256>
{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
  pname = "namespace-devbox";
  version = "0.0.185";

  src = fetchurl {
    url = "https://get.namespace.so/packages/devbox/v${version}/devbox_${version}_darwin_arm64.tar.gz";
    hash = "sha256-q70YEKvJvo62tFFJVaXQ/KFoCVkKMNrEvzQ66SWREt0=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 devbox $out/bin/devbox
    runHook postInstall
  '';

  meta.mainProgram = "devbox";
}
