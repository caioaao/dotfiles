# Anytype - Local-first knowledge management
# Source: https://github.com/anyproto/anytype-ts

{ pkgs, lib, ... }:

{
  environment.systemPackages = [
    (pkgs.appimageTools.wrapType2 rec {
      pname = "anytype";
      version = "0.54.1";

      src = pkgs.fetchurl {
        url = "https://anytype-release.fra1.cdn.digitaloceanspaces.com/Anytype-${version}.AppImage";
        hash = "sha256-TWXxZ4eYowVjNMu7OQB56JiB0CZYEcggyIHqH057oL4=";
      };

      extraInstallCommands = let
        contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
      in ''
        mkdir -p "$out/share/applications"
        cp -r ${contents}/usr/share/* "$out/share"
        cp "${contents}/${pname}.desktop" "$out/share/applications/" || true
        substituteInPlace $out/share/applications/${pname}.desktop --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      '';

      meta = with lib; {
        description = "Local-first, P2P, E2E-encrypted knowledge OS";
        homepage = "https://anytype.io";
        changelog = "https://github.com/anyproto/anytype-ts/releases/tag/v${version}";
        platforms = [ "x86_64-linux" ];
        license = licenses.unfree;  # Any Source Available License 1.0
        mainProgram = "anytype";
      };
    })
  ];
}
