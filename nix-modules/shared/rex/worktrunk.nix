{ lib, stdenvNoCC, fetchFromGitHub, makeWrapper, bash, worktrunk, git, fzf, jq, coreutils, gawk, gnused }:
stdenvNoCC.mkDerivation {
  pname = "rex-worktrunk";
  version = "0.1.0-dcfd281";
  src = fetchFromGitHub {
    owner = "haxybaxy";
    repo = "rex-worktrunk";
    rev = "dcfd281232beaab2606d1eb4f0deffa16e4762ed";
    hash = "sha256-GcUI8aLFyMl+Oeu31WwnaqD2o/Wb+4f2IQJWY+YPYqs=";
  };
  patches = [ ./session-safety.patch ];
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ git jq worktrunk ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/home/.config"
    mkdir -p "$XDG_CONFIG_HOME"
    bash test/list_test.sh
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/rex/rex-worktrunk" "$out/share/licenses/rex-worktrunk" "$out/bin"
    cp init.lua worktrunk.sh "$out/share/rex/rex-worktrunk/"
    cp LICENSE "$out/share/licenses/rex-worktrunk/"
    substituteInPlace "$out/share/rex/rex-worktrunk/worktrunk.sh" \
      --replace-fail '#!/usr/bin/env bash' '#!${bash}/bin/bash'
    chmod +x "$out/share/rex/rex-worktrunk/worktrunk.sh"
    makeWrapper "$out/share/rex/rex-worktrunk/worktrunk.sh" "$out/bin/rex-worktrunk-picker" \
      --prefix PATH : ${lib.makeBinPath [ bash worktrunk git fzf jq coreutils gawk gnused ]}
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    # Run the same observable assertions against the installed wrapper.
    substituteInPlace test/list_test.sh \
      --replace-fail 'script=$root/worktrunk.sh' 'script=$out/bin/rex-worktrunk-picker'
    bash test/list_test.sh
  '';
  meta = {
    description = "Repository-scoped Worktrunk pickers for Rex";
    homepage = "https://github.com/haxybaxy/rex-worktrunk";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
