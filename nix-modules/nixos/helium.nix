# Helium browser - privacy-focused Chromium-based browser
# Source: https://github.com/nix-community/nur-combined/blob/main/repos/Ev357/pkgs/helium/default.nix

{ pkgs, lib, ... }:

let
  pname = "helium";
  version = "0.8.5.1";

  heliumSrc = let
    sourceMap = {
      x86_64-linux = pkgs.fetchurl {
        url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
        hash = "sha256-jFSLLDsHB/NiJqFmn8S+JpdM8iCy3Zgyq+8l4RkBecM=";
      };
      aarch64-linux = pkgs.fetchurl {
        url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-arm64.AppImage";
        hash = "sha256-UUyC19Np3IqVX3NJVLBRg7YXpw0Qzou4pxJURYFLzZ4=";
      };
    };
  in sourceMap.${pkgs.stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}");

  # Extract AppImage and bundle WidevineCdm next to the binary
  extracted = pkgs.appimageTools.extractType2 { inherit pname version; src = heliumSrc; };
  extractedWithWidevine = pkgs.runCommand "${pname}-${version}-extracted" {} ''
    cp -a ${extracted} $out
    chmod -R u+w $out/opt/helium
    cp -a ${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm $out/opt/helium/
  '';
in
{
  environment.systemPackages = [
    (pkgs.appimageTools.wrapAppImage {
      inherit pname version;
      src = extractedWithWidevine;

      extraInstallCommands = ''
        mkdir -p "$out/share/applications"
        mkdir -p "$out/share/lib/helium"
        cp -r ${extractedWithWidevine}/opt/helium/locales "$out/share/lib/helium"
        cp -r ${extractedWithWidevine}/usr/share/* "$out/share"
        cp "${extractedWithWidevine}/${pname}.desktop" "$out/share/applications/"
        substituteInPlace $out/share/applications/${pname}.desktop --replace-fail 'Exec=AppRun' 'Exec=${pname}'

        # Write Widevine component hint file to the correct user data dir
        mv "$out/bin/${pname}" "$out/bin/.${pname}-wrapped"
        cat > "$out/bin/${pname}" <<'WRAPPER'
#!/bin/sh
CDM_DIR="$HOME/.config/net.imput.helium/WidevineCdm"
mkdir -p "$CDM_DIR"
cat > "$CDM_DIR/latest-component-updated-widevine-cdm" <<HINT
{"Path":"@widevineCdmPath@","LastBundledVersion":"4.10.2891.0"}
HINT
SELF="$(readlink -f "$0")"
exec "$(dirname "$SELF")/.helium-wrapped" "$@"
WRAPPER
        substituteInPlace "$out/bin/${pname}" \
          --replace-fail '@widevineCdmPath@' '${extractedWithWidevine}/opt/helium/WidevineCdm'
        chmod +x "$out/bin/${pname}"
      '';

      meta = with lib; {
        description = "Private, fast, and honest web browser based on Chromium";
        homepage = "https://github.com/imputnet/helium-chromium";
        changelog = "https://github.com/imputnet/helium-linux/releases/tag/${version}";
        platforms = [ "x86_64-linux" "aarch64-linux" ];
        license = licenses.gpl3;
        mainProgram = "helium";
      };
    })
  ];
}
