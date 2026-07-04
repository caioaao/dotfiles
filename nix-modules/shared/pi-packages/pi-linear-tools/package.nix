{
  buildPiPackage,
  fetchFromGitHub,
  lib,
}:

# Linear SDK tools for pi. Upstream ships its own package-lock.json.
buildPiPackage rec {
  pname = "pi-linear-tools";
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "fink-andreas";
    repo = "pi-linear-tools";
    rev = "v${version}";
    hash = "sha256-uIjjFD0/E8sWKtxVlYVarHxPEW/PPYZ4mtC5+weFhYI=";
  };

  npmDepsHash = "sha256-fyg/ISXyBs64zEkOfMzPbUzIEbjGGpaUgpxTDWDl4gE=";

  meta = {
    description = "Pi extension with Linear SDK tools and configuration commands";
    homepage = "https://github.com/fink-andreas/pi-linear-tools";
    license = lib.licenses.mit;
  };
}
