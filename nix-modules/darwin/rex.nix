# Rex for macOS, including its matching server/CLI. Not nixpkgs.rex (RexOps).
# Pin the build as well as the short version; Preview builds share 0.1.0.
# Update from https://blob.superlogical.com/public/rex-app/preview/appcast.xml
# and prefetch the versioned DMG with `nix store prefetch-file --json <url>`.
# Preserve the vendor signature: no patching, stripping, or in-app updates.
{ lib, stdenvNoCC, fetchurl, undmg }:

stdenvNoCC.mkDerivation rec {
  pname = "rex-macos";
  version = "0.1.0-1956";

  src = fetchurl {
    url = "https://blob.superlogical.com/public/rex-app/preview/Rex-${version}.dmg";
    hash = "sha256-HyRgH0lj41d+34NngLIdBQXiJ66YHVE4ZZ/H9ouPum4=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = "Rex Beta.app";
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Rex Beta.app" "$out/bin"
    cp -R . "$out/Applications/Rex Beta.app"
    ln -s "../Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" "$out/bin/rex"

    runHook postInstall
  '';

  meta = {
    description = "Rex terminal multiplexer for macOS with its bundled server and CLI";
    homepage = "https://www.superlogical.com/rex";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    mainProgram = "rex";
  };
}
