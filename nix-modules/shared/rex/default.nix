{ pkgs, ... }: {
  environment.systemPackages = [ (pkgs.callPackage ./worktrees {}) ];
  environment.pathsToLink = [ "/share/rex" ];
}
