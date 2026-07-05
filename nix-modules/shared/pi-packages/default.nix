{
  symlinkJoin,
  callPackage,
}:

# Pi packages (extensions) as nix derivations, merged into one bundle.
# Each package lands at <bundle>/share/pi/packages/<name>; via
# environment.systemPackages that becomes
# /run/current-system/sw/share/pi/packages/<name>, which is what
# ~/.pi/agent/settings.json references in its `packages` list.
let
  buildPiPackage = callPackage ./build-pi-package.nix { };
in
symlinkJoin {
  name = "pi-packages";
  paths = [
    (callPackage ./pi-fff/package.nix { inherit buildPiPackage; })
    (callPackage ./pi-linear-tools/package.nix { inherit buildPiPackage; })
    (callPackage ./pi-observer/extension/package.nix { inherit buildPiPackage; })
  ];
}
