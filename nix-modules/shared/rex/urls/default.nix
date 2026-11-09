{ lib, stdenvNoCC, makeWrapper, python3, fzf, xdg-utils }:
stdenvNoCC.mkDerivation {
  pname = "rex-urls";
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
    mkdir -p "$out/share/rex/urls" "$out/bin"
    cp init.lua picker.py "$out/share/rex/urls/"
    makeWrapper ${python3}/bin/python3 "$out/bin/rex-url-picker" \
      --add-flags "$out/share/rex/urls/picker.py" \
      --prefix PATH : ${lib.makeBinPath ([ fzf ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ xdg-utils ])}
    runHook postInstall
  '';
  meta = {
    description = "Rex terminal URL picker using fzf";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
