{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  fd,
  ripgrep,
}:

let
  version = "0.70.5";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-DpT12PmbDcnLWtMkyxz6vrYA5EV20MDRf8rnA6ByMRU=";
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
  npmDepsHash = "sha256-pcIf6NrV8l2tzhlrs3MvHIDgz8BLr+vaSIKu5cXPtls=";
  makeCacheWritable = true;
  dontNpmBuild = true;
  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [ fd ripgrep ]} \
      --set PI_SKIP_VERSION_CHECK 1
  '';
}
