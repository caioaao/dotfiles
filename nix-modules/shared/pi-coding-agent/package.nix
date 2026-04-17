{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  fd,
  ripgrep,
}:

let
  version = "0.67.6";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-Iut4BnDx3OzdrSpAf2IPW4oh2/99CHxYEJMVPieeu3Q=";
  };
  srcWithLock = runCommand "pi-coding-agent-${version}-src" {} ''
    mkdir -p $out
    tar -xzf ${tarball} -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit version;
  src = srcWithLock;
  npmDepsHash = "sha256-bjPrS+6XVoh6IbBkg4a84i4Iw6ycp3AL5uvOXVgC1fE=";
  makeCacheWritable = true;
  dontNpmBuild = true;
  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [ fd ripgrep ]} \
      --set PI_SKIP_VERSION_CHECK 1
  '';
}
