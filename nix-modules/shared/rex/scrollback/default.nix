{ lib, stdenvNoCC, lua5_1, zsh, xdg-utils }:
stdenvNoCC.mkDerivation {
  pname = "rex-scrollback-picker";
  version = "1";
  src = ./.;
  doCheck = true;
  nativeCheckInputs = [ lua5_1 ];
  checkPhase = ''
    runHook preCheck
    lua test_picker.lua
    runHook postCheck
  '';
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/rex/scrollback"
    cp extract.lua "$out/share/rex/scrollback/"
    substitute init.lua "$out/share/rex/scrollback/init.lua" \
      --replace-fail '@zsh@' '${zsh}/bin/zsh' \
      --replace-fail '@urlOpener@' '${if stdenvNoCC.hostPlatform.isDarwin then "/usr/bin/open" else "${xdg-utils}/bin/xdg-open"}'
    runHook postInstall
  '';
  meta = {
    description = "Native Rex picker for URLs and file paths from terminal scrollback";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
