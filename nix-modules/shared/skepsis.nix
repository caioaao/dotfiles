# Upstream's npm tarball bundles the CLI and frontend; no npm install/build needed.
# Update version and hash with `nix store prefetch-file --json <url>`.
{ lib, stdenvNoCC, fetchurl, makeWrapper, nodejs }:

stdenvNoCC.mkDerivation rec {
  pname = "skepsis";
  version = "0.6.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@oxide/skepsis/-/skepsis-${version}.tgz";
    hash = "sha256-zRoWPWm0Qhj0j+OR6CKoBXfSeqp413iKlYxPmFguh2M=";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/skepsis" "$out/bin"
    # Preserve ESM package metadata and every frontend asset beside the CLI.
    cp -r dist package.json "$out/lib/skepsis/"
    makeWrapper ${nodejs}/bin/node "$out/bin/skepsis" \
      --add-flags "$out/lib/skepsis/dist/cli.js"
    runHook postInstall
  '';

  # git is already installed by the shared configuration; jj is optional.
  meta = {
    description = "Local browser-based code review UI for git and jj diffs";
    homepage = "https://github.com/oxidecomputer/skepsis";
    license = lib.licenses.mpl20;
    mainProgram = "skepsis";
    platforms = lib.platforms.unix;
  };
}
