{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.callPackage ./worktrees {})
    (pkgs.callPackage ./urls {})
  ];
  environment.pathsToLink = [ "/share/rex" ];
}
