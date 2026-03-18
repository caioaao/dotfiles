# Paper - Design tool
# Source: https://paper.design

{ pkgs, lib, ... }:

{
  environment.systemPackages = [
    (pkgs.appimageTools.wrapType2 rec {
      pname = "paper-desktop";
      version = "26031739o5exfj4";

      src = pkgs.fetchurl {
        url = "https://download.paper.design/linux/appImage";
        hash = "sha256-ZXS0i3mIXs/rbXaSto7f+VAG93vX/vOgK6gPvtTVnXc=";
      };

      extraPkgs = _: [ pkgs.xdg-utils ];

      extraInstallCommands = let
        contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
      in ''
        mkdir -p "$out/share/applications"
        cp -r ${contents}/usr/share/* "$out/share"
        cp "${contents}/${pname}.desktop" "$out/share/applications/" || true
        substituteInPlace $out/share/applications/${pname}.desktop --replace-fail 'Exec=AppRun' "Exec=$out/bin/${pname}"
      '';

      meta = with lib; {
        description = "Paper - Design tool";
        homepage = "https://paper.design";
        platforms = [ "x86_64-linux" ];
        license = licenses.unfree;
        mainProgram = "paper-desktop";
      };
    })
  ];
}
