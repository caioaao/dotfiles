{ lib, stdenvNoCC, makeWrapper, bash, worktrunk, git, fzf, jq, coreutils, gawk, gnused, python3 }:
stdenvNoCC.mkDerivation {
  pname = "rex-worktrees";
  version = "1";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ git jq worktrunk fzf coreutils gawk gnused python3 ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/home/.config"
    mkdir -p "$XDG_CONFIG_HOME"
    bash test/picker.sh
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/rex/worktrees" "$out/share/licenses/rex-worktrees" "$out/bin"
    cp init.lua sessions.lua picker.sh "$out/share/rex/worktrees/"
    cp LICENSE "$out/share/licenses/rex-worktrees/"
    substituteInPlace "$out/share/rex/worktrees/picker.sh" \
      --replace-fail '#!/usr/bin/env bash' '#!${bash}/bin/bash'
    chmod +x "$out/share/rex/worktrees/picker.sh"
    makeWrapper "$out/share/rex/worktrees/picker.sh" "$out/bin/rex-worktree-picker" \
      --prefix PATH : ${lib.makeBinPath [ bash worktrunk git fzf jq coreutils gawk gnused ]}
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    PICKER="$out/bin/rex-worktree-picker" bash test/picker.sh
  '';
  meta = {
    description = "Local Rex worktree actions and Worktrunk/fzf picker";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
