{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.callPackage ./worktrees {})
    (pkgs.callPackage ./scrollback {})
  ];
  environment.pathsToLink = [ "/share/rex" ];
}
