{
  buildPiPackage,
  fetchurl,
  lib,
}:

# FFF-powered fuzzy file/content search tools (fffind, ffgrep).
# npm tarball ships no lock file, so one is vendored here. To regenerate:
#   npm install --package-lock-only --legacy-peer-deps
# in the extracted tarball, then copy package-lock.json next to this file.
buildPiPackage rec {
  pname = "pi-fff";
  version = "0.9.5";

  src = fetchurl {
    url = "https://registry.npmjs.org/@ff-labs/pi-fff/-/pi-fff-${version}.tgz";
    hash = "sha256-DAsJFivVU6Hy/r1z/Q2qz7XaorK73QqZzu/BXm3n91k=";
  };
  packageLock = ./package-lock.json;

  npmDepsHash = "sha256-Kf13buPDLkPxiq/SVhub+C1cw3WkhgxQtl67rcsj178=";

  meta = {
    description = "pi extension: FFF-powered fuzzy file and content search";
    homepage = "https://github.com/dmtrKovalenko/fff/tree/main/packages/pi-fff";
    license = lib.licenses.mit;
  };
}
