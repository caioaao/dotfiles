{ pkgs, ... }: {
  environment.systemPackages = [ (pkgs.callPackage ./worktrunk.nix {}) ];
  environment.pathsToLink = [ "/share/rex" ];
}
