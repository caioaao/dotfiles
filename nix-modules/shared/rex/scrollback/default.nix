{ lib, stdenvNoCC, makeWrapper, python3, fzf, xdg-utils }:
stdenvNoCC.mkDerivation {
  pname = "rex-scrollback-picker";
  version = "1";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  doCheck = true;
  nativeCheckInputs = [ python3 ];
  checkPhase = ''
    runHook preCheck
    python3 -m unittest test_picker.py
    runHook postCheck
  '';
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/rex/scrollback" "$out/bin"
    cp init.lua picker.py "$out/share/rex/scrollback/"
    makeWrapper ${python3}/bin/python3 "$out/bin/rex-scrollback-picker" \
      --add-flags "$out/share/rex/scrollback/picker.py" \
      --prefix PATH : ${lib.makeBinPath ([ fzf ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ xdg-utils ])}
    runHook postInstall
  '';
  meta = {
    description = "Pick URLs and file paths from Rex terminal scrollback with fzf";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
